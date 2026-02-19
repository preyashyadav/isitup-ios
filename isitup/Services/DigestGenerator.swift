//
//  DigestGenerator.swift
//  isitup
//
//  Created by Preyash Yadav on 2/19/26.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol DigestGenerating: AnyObject {
  var isFeatureAvailable: Bool { get }
  func updateServices(_ services: [ServiceStatus])
  func generateDailyDigest() async -> String?
}

final class DigestGenerator: DigestGenerating {
  private let nowProvider: () -> Date
  private var servicesSnapshot: [ServiceStatus] = []

  init(nowProvider: @escaping () -> Date = Date.init) {
    self.nowProvider = nowProvider
  }

  var isFeatureAvailable: Bool {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else { return false }
    return SystemLanguageModel.default.isAvailable
#else
    return false
#endif
  }

  func updateServices(_ services: [ServiceStatus]) {
    servicesSnapshot = services
  }

  func generateDailyDigest() async -> String? {
    guard isFeatureAvailable else { return nil }

    let prompt = buildPrompt(from: servicesSnapshot)
    guard !prompt.isEmpty else { return nil }

#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else { return nil }

    let session = LanguageModelSession(model: .default)
    do {
      let response = try await session.respond(to: prompt)
      let digest = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
      return digest.isEmpty ? nil : digest
    } catch {
      return nil
    }
#else
    return nil
#endif
  }

  private func buildPrompt(from services: [ServiceStatus]) -> String {
    let now = nowProvider()
    let windowStart = now.addingTimeInterval(-24 * 60 * 60)

    let serviceLines = summarizeServices(services, windowStart: windowStart)
    guard !serviceLines.isEmpty else { return "" }

    let cappedLines: [String]
    var header = "Daily infrastructure health summary input:"
    if serviceLines.count > 20 {
      cappedLines = Array(serviceLines.prefix(20))
      let hidden = serviceLines.count - 20
      header += " (showing 20 of \(serviceLines.count) services; \(hidden) summarized separately)"
    } else {
      cappedLines = serviceLines
    }

    let hiddenSummary: String
    if serviceLines.count > 20 {
      hiddenSummary = "Additional services not listed individually: \(serviceLines.count - 20)"
    } else {
      hiddenSummary = "No additional hidden services."
    }

    let correlationLines = correlatedFailureLines(services, windowStart: windowStart)
    let correlationSection = correlationLines.isEmpty
      ? "No correlated multi-service outages detected in the last 24h."
      : correlationLines.joined(separator: "\n")

    return """
    \(header)
    \(cappedLines.joined(separator: "\n"))
    \(hiddenSummary)

    Correlated failures (within 5-minute windows):
    \(correlationSection)

    Write a 2-3 sentence plain English summary of overall infrastructure health.
    Highlight concerning patterns and likely shared-cause incidents when applicable.
    Keep it concise and actionable.
    """
  }

  private func summarizeServices(_ services: [ServiceStatus], windowStart: Date) -> [String] {
    services.map { service in
      let recent = service.samples
        .filter { $0.at >= windowStart }
        .sorted { $0.at < $1.at }

      let avgLatency: String = {
        let latencies = recent.compactMap(\.responseTimeMs)
        guard !latencies.isEmpty else { return "n/a" }
        let mean = Double(latencies.reduce(0, +)) / Double(latencies.count)
        return "\(Int(mean.rounded()))ms"
      }()

      let latestLatency: String = {
        guard let latest = recent.compactMap(\.responseTimeMs).last else { return "n/a" }
        return "\(latest)ms"
      }()

      let trend = latencyTrend(in: recent)

      let outages = outageCount(in: recent)
      return "- \(service.name) | status: \(service.state.rawValue) | avg latency (24h): \(avgLatency) | latest latency: \(latestLatency) | trend: \(trend) | outages (24h): \(outages)"
    }
  }

  private func latencyTrend(in samples: [CheckSample]) -> String {
    let latencies = samples.compactMap(\.responseTimeMs)
    guard latencies.count >= 6 else { return "insufficient data" }

    let latestWindow = Array(latencies.suffix(3))
    let previousWindow = Array(latencies.dropLast(3).suffix(3))

    guard !latestWindow.isEmpty, !previousWindow.isEmpty else { return "insufficient data" }

    let latestAvg = Double(latestWindow.reduce(0, +)) / Double(latestWindow.count)
    let previousAvg = Double(previousWindow.reduce(0, +)) / Double(previousWindow.count)

    guard previousAvg > 0 else { return "stable" }

    let changeRatio = (latestAvg - previousAvg) / previousAvg
    let changePercent = Int((changeRatio * 100).rounded())

    if changeRatio >= 0.15 {
      return "increasing (+\(changePercent)%)"
    }
    if changeRatio <= -0.15 {
      return "decreasing (\(changePercent)%)"
    }
    return "stable (\(changePercent)%)"
  }

  private func outageCount(in samples: [CheckSample]) -> Int {
    guard !samples.isEmpty else { return 0 }

    func isOutage(_ state: HealthState) -> Bool {
      state == .down || state == .error
    }

    var count = 0
    var previouslyOutage = false

    for sample in samples {
      let currentlyOutage = isOutage(sample.state)
      if currentlyOutage && !previouslyOutage {
        count += 1
      }
      previouslyOutage = currentlyOutage
    }

    return count
  }

  private func correlatedFailureLines(_ services: [ServiceStatus], windowStart: Date) -> [String] {
    let bucketSize: TimeInterval = 5 * 60
    var bucketToServices: [Int: Set<String>] = [:]

    for service in services {
      let recent = service.samples
        .filter { $0.at >= windowStart }
        .sorted { $0.at < $1.at }

      let transitionTimes = outageTransitionTimes(in: recent)
      for timestamp in transitionTimes {
        let bucket = Int(timestamp.timeIntervalSince1970 / bucketSize)
        bucketToServices[bucket, default: []].insert(service.name)
      }
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short

    return bucketToServices
      .filter { $0.value.count >= 2 }
      .sorted { $0.key < $1.key }
      .map { bucket, names in
        let at = Date(timeIntervalSince1970: TimeInterval(bucket) * bucketSize)
        let joined = names.sorted().joined(separator: ", ")
        return "- \(names.count) services down around \(formatter.string(from: at)): \(joined)"
      }
  }

  private func outageTransitionTimes(in samples: [CheckSample]) -> [Date] {
    func isOutage(_ state: HealthState) -> Bool {
      state == .down || state == .error
    }

    var times: [Date] = []
    var previouslyOutage = false

    for sample in samples {
      let currentlyOutage = isOutage(sample.state)
      if currentlyOutage && !previouslyOutage {
        times.append(sample.at)
      }
      previouslyOutage = currentlyOutage
    }

    return times
  }
}
