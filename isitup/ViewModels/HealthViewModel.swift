//
//  HealthViewModel.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation
import Combine
#if canImport(AppIntents)
import AppIntents
#endif

@MainActor
final class HealthViewModel: ObservableObject {
  @Published private(set) var services: [ServiceStatus] = []
  @Published var notifyOnDown: Bool = true
  @Published private(set) var dailyDigest: String?
  @Published private(set) var dailyDigestGeneratedAt: Date?
  @Published private(set) var isGeneratingDigest: Bool = false
  @Published var debugSimulationEnabled: Bool = false {
    didSet {
      if debugSimulationEnabled && debugAdditionalLatencyMs < 1 {
        debugAdditionalLatencyMs = 1200
      }
      persistDebugSimulationConfigIfReady()
    }
  }
  @Published var debugAdditionalLatencyMs: Double = 0 {
    didSet {
      let clamped = min(5000.0, max(0.0, debugAdditionalLatencyMs))
      if clamped != debugAdditionalLatencyMs {
        debugAdditionalLatencyMs = clamped
        return
      }
      persistDebugSimulationConfigIfReady()
    }
  }

  private let client: HealthChecking
  private let store: ServiceStore
  private let sampleStore: SampleStoring
  private let anomalyDetector: AnomalyDetecting
  private let digestGenerator: DigestGenerating
  private let debugSimulationStore: DebugSimulationStoring
  private let notificationGrouper: NotificationGrouping
  private let notificationManager: NotificationManager
  private let userDefaults: UserDefaults
  private var hasLoadedDebugSimulationConfig = false

  private let digestTextKey = "isitup.digest.text"
  private let digestTimestampKey = "isitup.digest.generatedAt"

  init(
    useMock: Bool,
    store: ServiceStore? = nil,
    sampleStore: SampleStoring? = nil,
    anomalyDetector: AnomalyDetecting? = nil,
    digestGenerator: DigestGenerating? = nil,
    debugSimulationStore: DebugSimulationStoring? = nil,
    notificationGrouper: NotificationGrouping? = nil,
    userDefaults: UserDefaults = .standard,
    notificationManager: NotificationManager? = nil
  ) {
    let resolvedStore = store ?? ServiceStore.shared
    let resolvedSampleStore = sampleStore ?? SampleStore.shared
    let resolvedAnomalyDetector = anomalyDetector ?? AnomalyDetector()
    let resolvedDigestGenerator = digestGenerator ?? DigestGenerator()
    let resolvedDebugSimulationStore = debugSimulationStore ?? DebugSimulationStore.shared
    let resolvedNotificationGrouper = notificationGrouper ?? NotificationGrouper()
    let resolvedNotificationManager = notificationManager ?? NotificationManager.shared

    self.client = useMock ? MockHealthClient() : URLSessionHealthClient()
    self.store = resolvedStore
    self.sampleStore = resolvedSampleStore
    self.anomalyDetector = resolvedAnomalyDetector
    self.digestGenerator = resolvedDigestGenerator
    self.debugSimulationStore = resolvedDebugSimulationStore
    self.notificationGrouper = resolvedNotificationGrouper
    self.userDefaults = userDefaults
    self.notificationManager = resolvedNotificationManager

    let debugConfig = resolvedDebugSimulationStore.loadConfig()
    self.debugSimulationEnabled = debugConfig.isEnabled
    self.debugAdditionalLatencyMs = Double(debugConfig.additionalLatencyMs)
    self.hasLoadedDebugSimulationConfig = true

    reloadFromStore()
    loadCachedDigest()
  }

  // MARK: - Config

  func reloadFromStore() {
    let configs = store.loadConfigs()
    self.services = configs.map { cfg in
      let serviceID = UUID(uuidString: cfg.id) ?? UUID()
      let persistedSamples = sampleStore.loadSamples(for: serviceID.uuidString)
      return ServiceStatus(
        id: serviceID,
        name: cfg.name,
        endpoint: URL(string: cfg.url),
        state: .unknown,
        lastCheckedAt: nil,
        message: nil,
        samples: persistedSamples
      )
    }
  }

  func saveConfigs(_ configs: [ServiceConfig]) {
    store.saveConfigs(configs)
    reloadFromStore()
  }

  func currentConfigs() -> [ServiceConfig] {
    services.map { s in
      ServiceConfig(id: s.id.uuidString, name: s.name, url: s.endpoint?.absoluteString ?? "")
    }
  }

  func resetConfigsToBundled() {
    _ = store.resetToBundled()
    reloadFromStore()
  }

  func clearHistory() {
    sampleStore.clearAllSamples()

    for idx in services.indices {
      services[idx].samples = []
      services[idx].state = .unknown
      services[idx].lastCheckedAt = nil
      services[idx].message = nil
    }

    clearCachedDigest()
  }

  var isDigestFeatureAvailable: Bool {
    digestGenerator.isFeatureAvailable
  }

  func refreshDailyDigestIfNeeded(force: Bool = false) async {
    guard isDigestFeatureAvailable else {
      dailyDigest = nil
      dailyDigestGeneratedAt = nil
      return
    }

    if !force,
       let generatedAt = dailyDigestGeneratedAt,
       Calendar.current.isDateInToday(generatedAt),
       dailyDigest != nil {
      return
    }

    isGeneratingDigest = true
    defer { isGeneratingDigest = false }

    digestGenerator.updateServices(services)
    let generated = await digestGenerator.generateDailyDigest()
    guard let generated, !generated.isEmpty else { return }

    dailyDigest = generated
    dailyDigestGeneratedAt = Date()
    persistCachedDigest()
  }

  // MARK: - Notifications

  private func shouldNotifyForState(_ state: HealthState) -> Bool {
    let bad: Set<HealthState> = [.down, .error]
    return bad.contains(state)
  }

  private func maybeNotifyDown(idx: Int) {
    let newState = services[idx].state
    guard notifyOnDown, shouldNotifyForState(newState) else { return }

    let name = services[idx].name
    let serviceID = services[idx].id.uuidString
    let url = services[idx].endpoint?.absoluteString ?? "—"
    let detail = services[idx].message

    Task {
      await notificationManager.notifyServiceDown(
        serviceID: serviceID,
        name: name,
        url: url,
        detail: detail
      )
    }
  }

  private func maybeNotifyDegrading(idx: Int, oldState: HealthState) {
    guard notifyOnDown else { return }
    guard services[idx].state == .degrading, oldState != .degrading else { return }

    let name = services[idx].name
    let serviceID = services[idx].id.uuidString
    let url = services[idx].endpoint?.absoluteString ?? "—"
    let detail = services[idx].message

    Task {
      await notificationManager.notifyServiceDegrading(
        serviceID: serviceID,
        name: name,
        url: url,
        detail: detail
      )
    }
  }

  private func applyDegradingIfNeeded(idx: Int) {
    guard services[idx].state == .healthy else { return }

    let trend = anomalyDetector.classify(samples: services[idx].samples)
    guard trend == .degrading else { return }

    services[idx].state = .degrading
    services[idx].message = appendDegradingHint(to: services[idx].message)
  }

  private func appendDegradingHint(to message: String?) -> String {
    let hint = "Latency degrading"
    guard let message, !message.isEmpty else { return hint }
    if message.localizedCaseInsensitiveContains("degrading") {
      return message
    }
    return "\(message) • \(hint)"
  }

  // MARK: - Health checks

  func check(serviceId: UUID) async {
    _ = await runCheck(serviceId: serviceId, emitDownNotificationImmediately: true)
  }

  /// Concurrent check-all 
  func checkAll() async {
    let ids = services.map { $0.id }
    var outcomes: [CheckOutcome] = []

    await withTaskGroup(of: CheckOutcome?.self) { group in
      for id in ids {
        group.addTask { [weak self] in
          await self?.runCheck(serviceId: id, emitDownNotificationImmediately: false)
        }
      }

      for await outcome in group {
        if let outcome {
          outcomes.append(outcome)
        }
      }
    }

    await handleCheckAllFailureNotifications(outcomes: outcomes)
    await donateCheckAllIntent()
  }

  private struct CheckOutcome {
    let serviceID: UUID
    let transitionedToFailure: Bool
    let transitionedToDegrading: Bool
  }

  private func runCheck(serviceId: UUID, emitDownNotificationImmediately: Bool) async -> CheckOutcome? {
    guard let idx = services.firstIndex(where: { $0.id == serviceId }) else { return nil }
    let oldState = services[idx].state
    let simulatedLatencyMs = currentSimulatedLatencyMs()

    services[idx].state = .checking
    services[idx].message = nil

    guard let url = services[idx].endpoint else {
      services[idx].lastCheckedAt = Date()
      services[idx].state = .error
      services[idx].message = withSimulationHint(
        "No endpoint configured",
        simulatedLatencyMs: simulatedLatencyMs
      )
      appendSample(
        idx: idx,
        statusCode: nil,
        responseTimeMs: nil,
        isSimulated: simulatedLatencyMs > 0
      )

      if emitDownNotificationImmediately {
        maybeNotifyDown(idx: idx)
      }

      return CheckOutcome(
        serviceID: serviceId,
        transitionedToFailure: transitionedToFailure(oldState: oldState, newState: services[idx].state),
        transitionedToDegrading: transitionedToDegrading(oldState: oldState, newState: services[idx].state)
      )
    }

    do {
      if simulatedLatencyMs > 0 {
        try? await Task.sleep(nanoseconds: UInt64(simulatedLatencyMs) * 1_000_000)
      }

      let res = try await client.check(url: url)
      services[idx].lastCheckedAt = Date()

      let code = res.statusCode
      if (200...399).contains(code) {
        services[idx].state = .healthy
        services[idx].message = "HTTP \(code)"
      } else {
        services[idx].state = .down
        services[idx].message = "HTTP \(code)"
      }
      services[idx].message = withSimulationHint(
        services[idx].message,
        simulatedLatencyMs: simulatedLatencyMs
      )

      appendSample(
        idx: idx,
        statusCode: code,
        responseTimeMs: res.responseTimeMs + simulatedLatencyMs,
        isSimulated: simulatedLatencyMs > 0
      )
      applyDegradingIfNeeded(idx: idx)

      if emitDownNotificationImmediately {
        maybeNotifyDown(idx: idx)
      }
      if emitDownNotificationImmediately {
        maybeNotifyDegrading(idx: idx, oldState: oldState)
      }

      return CheckOutcome(
        serviceID: serviceId,
        transitionedToFailure: transitionedToFailure(oldState: oldState, newState: services[idx].state),
        transitionedToDegrading: transitionedToDegrading(oldState: oldState, newState: services[idx].state)
      )
    } catch {
      services[idx].lastCheckedAt = Date()
      services[idx].state = .error
      services[idx].message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      services[idx].message = withSimulationHint(
        services[idx].message,
        simulatedLatencyMs: simulatedLatencyMs
      )

      appendSample(
        idx: idx,
        statusCode: nil,
        responseTimeMs: nil,
        isSimulated: simulatedLatencyMs > 0
      )
      if emitDownNotificationImmediately {
        maybeNotifyDown(idx: idx)
      }

      return CheckOutcome(
        serviceID: serviceId,
        transitionedToFailure: transitionedToFailure(oldState: oldState, newState: services[idx].state),
        transitionedToDegrading: transitionedToDegrading(oldState: oldState, newState: services[idx].state)
      )
    }
  }

  private func transitionedToFailure(oldState: HealthState, newState: HealthState) -> Bool {
    !isFailureState(oldState) && isFailureState(newState)
  }

  private func transitionedToDegrading(oldState: HealthState, newState: HealthState) -> Bool {
    oldState != .degrading && newState == .degrading
  }

  private func isFailureState(_ state: HealthState) -> Bool {
    state == .down || state == .error
  }

  private func handleCheckAllFailureNotifications(outcomes: [CheckOutcome]) async {
    guard notifyOnDown else { return }

    let newlyFailedServices = outcomes
      .filter(\.transitionedToFailure)
      .compactMap { outcome in
        services.first(where: { $0.id == outcome.serviceID })
      }
      .filter { isFailureState($0.state) }

    if !newlyFailedServices.isEmpty {
      let decision = notificationGrouper.decide(newlyFailedServices: newlyFailedServices)
      if decision.shouldSendGroupedNotification {
        await notificationManager.notifyGroupedOutage(serviceNames: newlyFailedServices.map(\.name))
      } else {
        for service in newlyFailedServices {
          await notificationManager.notifyServiceDown(
            serviceID: service.id.uuidString,
            name: service.name,
            url: service.endpoint?.absoluteString ?? "—",
            detail: service.message
          )
        }
      }
    }

    let newlyDegradingServices = outcomes
      .filter(\.transitionedToDegrading)
      .compactMap { outcome in
        services.first(where: { $0.id == outcome.serviceID })
      }
      .filter { $0.state == .degrading }

    if !newlyDegradingServices.isEmpty {
      let degradingDecision = notificationGrouper.decide(newlyFailedServices: newlyDegradingServices)
      if degradingDecision.shouldSendGroupedNotification {
        await notificationManager.notifyGroupedDegrading(serviceNames: newlyDegradingServices.map(\.name))
      } else {
        for service in newlyDegradingServices {
          await notificationManager.notifyServiceDegrading(
            serviceID: service.id.uuidString,
            name: service.name,
            url: service.endpoint?.absoluteString ?? "—",
            detail: service.message
          )
        }
      }
    }
  }

  private func appendSample(
    idx: Int,
    statusCode: Int?,
    responseTimeMs: Int?,
    isSimulated: Bool = false
  ) {
    let sample = CheckSample(
      at: Date(),
      state: services[idx].state,
      statusCode: statusCode,
      responseTimeMs: responseTimeMs,
      message: services[idx].message,
      isSimulated: isSimulated
    )
    services[idx].samples.append(sample)

    if services[idx].samples.count > 200 {
      services[idx].samples.removeFirst(services[idx].samples.count - 200)
    }

    _ = sampleStore.appendSample(sample, for: services[idx].id.uuidString)
  }

  private func currentSimulatedLatencyMs() -> Int {
    guard debugSimulationEnabled else { return 0 }
    return max(0, Int(debugAdditionalLatencyMs.rounded()))
  }

  private func withSimulationHint(_ message: String?, simulatedLatencyMs: Int) -> String? {
    guard simulatedLatencyMs > 0 else { return message }

    let hint = "+\(simulatedLatencyMs)ms simulated"
    guard let message, !message.isEmpty else { return hint }
    if message.localizedCaseInsensitiveContains("simulated") {
      return message
    }
    return "\(message) • \(hint)"
  }

  private func persistDebugSimulationConfigIfReady() {
    guard hasLoadedDebugSimulationConfig else { return }

    debugSimulationStore.saveConfig(
      DebugSimulationConfig(
        isEnabled: debugSimulationEnabled,
        additionalLatencyMs: Int(debugAdditionalLatencyMs.rounded())
      )
    )
  }

  private func donateCheckAllIntent() async {
#if canImport(AppIntents)
    if #available(iOS 16.0, *) {
      do {
        if #available(iOS 17.2, *) {
          _ = try await CheckAllServicesIntent().donate()
        }
      } catch {
        // Ignore donation failures; checks should still succeed.
      }
    }
#endif
  }

  private func loadCachedDigest() {
    guard let digest = userDefaults.string(forKey: digestTextKey),
          !digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      dailyDigest = nil
      dailyDigestGeneratedAt = nil
      return
    }

    dailyDigest = digest
    dailyDigestGeneratedAt = userDefaults.object(forKey: digestTimestampKey) as? Date
  }

  private func persistCachedDigest() {
    userDefaults.set(dailyDigest, forKey: digestTextKey)
    userDefaults.set(dailyDigestGeneratedAt, forKey: digestTimestampKey)
  }

  private func clearCachedDigest() {
    dailyDigest = nil
    dailyDigestGeneratedAt = nil
    userDefaults.removeObject(forKey: digestTextKey)
    userDefaults.removeObject(forKey: digestTimestampKey)
  }
}

// MARK: - Summary

struct HealthSummary {
  let total: Int
  let healthy: Int
  let degrading: Int
  let down: Int
  let error: Int
  let checking: Int
}

extension HealthViewModel {
  var summary: HealthSummary {
    let total = services.count
    let healthy = services.filter { $0.state == .healthy }.count
    let degrading = services.filter { $0.state == .degrading }.count
    let down = services.filter { $0.state == .down }.count
    let error = services.filter { $0.state == .error }.count
    let checking = services.filter { $0.state == .checking }.count
    return HealthSummary(
      total: total,
      healthy: healthy,
      degrading: degrading,
      down: down,
      error: error,
      checking: checking
    )
  }
}
