//
//  AnomalyDetector.swift
//  isitup
//
//  Created by Preyash Yadav on 2/19/26.
//

import Foundation

enum AnomalyTrend {
  case unknown
  case stable
  case degrading
}

protocol AnomalyDetecting: AnyObject {
  func classify(samples: [CheckSample]) -> AnomalyTrend
}

final class AnomalyDetector: AnomalyDetecting {
  private struct LatencyPoint {
    let latencyMs: Double
    let isSimulated: Bool
  }

  private let minimumSamples: Int
  private let rollingWindowSize: Int
  private let thresholdMultiplier: Double
  private let simulatedFallbackDegradingMs: Double

  init(
    minimumSamples: Int = 10,
    rollingWindowSize: Int = 50,
    thresholdMultiplier: Double = 2.5,
    simulatedFallbackDegradingMs: Double = 1800
  ) {
    self.minimumSamples = minimumSamples
    self.rollingWindowSize = rollingWindowSize
    self.thresholdMultiplier = thresholdMultiplier
    self.simulatedFallbackDegradingMs = simulatedFallbackDegradingMs
  }

  func classify(samples: [CheckSample]) -> AnomalyTrend {
    let recent = samples
      .filter { $0.state == .healthy || $0.state == .degrading }
      .compactMap { sample -> LatencyPoint? in
        guard let latency = sample.responseTimeMs else { return nil }
        return LatencyPoint(
          latencyMs: Double(latency),
          isSimulated: sample.isSimulated == true || isSimulatedSample(sample)
        )
      }
      .suffix(rollingWindowSize)

    guard let latestPoint = recent.last else {
      return .unknown
    }

    // Keep debug-simulated latency useful even with limited history.
    if latestPoint.isSimulated && recent.count < minimumSamples {
      return latestPoint.latencyMs >= simulatedFallbackDegradingMs ? .degrading : .unknown
    }

    guard recent.count >= minimumSamples else {
      return .unknown
    }

    // Compare newest point against a baseline built from prior points only.
    // If the newest point is simulated, only trust non-simulated history.
    let previous = Array(recent.dropLast())
    let preferredBaseline: [LatencyPoint]
    if latestPoint.isSimulated {
      let nonSimulated = previous.filter { !$0.isSimulated }
      guard !nonSimulated.isEmpty else {
        return latestPoint.latencyMs >= simulatedFallbackDegradingMs ? .degrading : .unknown
      }
      preferredBaseline = nonSimulated
    } else {
      preferredBaseline = previous
    }

    let baseline = preferredBaseline.map(\.latencyMs)
    guard !baseline.isEmpty else { return .unknown }

    let mean = baseline.reduce(0, +) / Double(baseline.count)
    let variance = baseline.reduce(0) { partial, value in
      let delta = value - mean
      return partial + (delta * delta)
    } / Double(baseline.count)
    let stddev = sqrt(variance)

    let stdThreshold = mean + (thresholdMultiplier * stddev)
    let simulatedAbsoluteThreshold = mean + 500.0

    let aboveStdThreshold = latestPoint.latencyMs > stdThreshold
    let aboveSimulatedThreshold = latestPoint.isSimulated && latestPoint.latencyMs > simulatedAbsoluteThreshold

    return (aboveStdThreshold || aboveSimulatedThreshold) ? .degrading : .stable
  }

  private func isSimulatedSample(_ sample: CheckSample) -> Bool {
    guard let message = sample.message else { return false }
    return message.localizedCaseInsensitiveContains("simulated")
  }
}
