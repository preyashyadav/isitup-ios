//
//  HealthViewModel.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation
import Combine

@MainActor
final class HealthViewModel: ObservableObject {
  @Published private(set) var services: [ServiceStatus] = []
  @Published var notifyOnDown: Bool = true

  private let client: HealthChecking
  private let store = ServiceStore.shared

  init(useMock: Bool) {
    self.client = useMock ? MockHealthClient() : URLSessionHealthClient()
    reloadFromStore()
  }

  // MARK: - Config

  func reloadFromStore() {
    let configs = store.loadConfigs()
    self.services = configs.map { cfg in
      ServiceStatus(
        id: UUID(),
        name: cfg.name,
        endpoint: URL(string: cfg.url),
        state: .unknown,
        lastCheckedAt: nil,
        message: nil,
        samples: []
      )
    }
  }

  func saveConfigs(_ configs: [ServiceConfig]) {
    store.saveConfigs(configs)
    reloadFromStore()
  }

  func currentConfigs() -> [ServiceConfig] {
    services.map { s in
      ServiceConfig(name: s.name, url: s.endpoint?.absoluteString ?? "")
    }
  }

  func resetConfigsToBundled() {
    _ = store.resetToBundled()
    reloadFromStore()
  }

  // MARK: - Notifications

  private func shouldAlertTransition(old: HealthState, new: HealthState) -> Bool {
    let bad: Set<HealthState> = [.down, .error]
    return !bad.contains(old) && bad.contains(new)
  }

  private func maybeNotifyDown(idx: Int, oldState: HealthState) {
    let newState = services[idx].state
    guard notifyOnDown, shouldAlertTransition(old: oldState, new: newState) else { return }

    let name = services[idx].name
    let url = services[idx].endpoint?.absoluteString ?? "—"
    let detail = services[idx].message

    Task {
      await NotificationManager.shared.notifyServiceDown(name: name, url: url, detail: detail)
    }
  }

  // MARK: - Health checks

  func check(serviceId: UUID) async {
    guard let idx = services.firstIndex(where: { $0.id == serviceId }) else { return }

    let oldState = services[idx].state

    services[idx].state = .checking
    services[idx].message = nil

    guard let url = services[idx].endpoint else {
      services[idx].lastCheckedAt = Date()
      services[idx].state = .error
      services[idx].message = "No endpoint configured"
      appendSample(idx: idx, statusCode: nil)
      maybeNotifyDown(idx: idx, oldState: oldState)
      return
    }

    do {
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

      appendSample(idx: idx, statusCode: code)
      maybeNotifyDown(idx: idx, oldState: oldState)
    } catch {
      services[idx].lastCheckedAt = Date()
      services[idx].state = .error
      services[idx].message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

      appendSample(idx: idx, statusCode: nil)
      maybeNotifyDown(idx: idx, oldState: oldState)
    }
  }

  /// Concurrent check-all 
  func checkAll() async {
    let ids = services.map { $0.id }
    await withTaskGroup(of: Void.self) { group in
      for id in ids {
        group.addTask { [weak self] in
          await self?.check(serviceId: id)
        }
      }
    }
  }

  private func appendSample(idx: Int, statusCode: Int?) {
    let sample = CheckSample(
      at: Date(),
      state: services[idx].state,
      statusCode: statusCode,
      message: services[idx].message
    )
    services[idx].samples.append(sample)

    if services[idx].samples.count > 50 {
      services[idx].samples.removeFirst(services[idx].samples.count - 50)
    }
  }
}

// MARK: - Summary

struct HealthSummary {
  let total: Int
  let healthy: Int
  let down: Int
  let error: Int
  let checking: Int
}

extension HealthViewModel {
  var summary: HealthSummary {
    let total = services.count
    let healthy = services.filter { $0.state == .healthy }.count
    let down = services.filter { $0.state == .down }.count
    let error = services.filter { $0.state == .error }.count
    let checking = services.filter { $0.state == .checking }.count
    return HealthSummary(total: total, healthy: healthy, down: down, error: error, checking: checking)
  }
}

