//
//  DebugSimulationStore.swift
//  isitup
//
//  Created by Preyash Yadav on 2/19/26.
//

import Foundation

struct DebugSimulationConfig: Hashable {
  var isEnabled: Bool
  var additionalLatencyMs: Int
}

protocol DebugSimulationStoring: AnyObject {
  func loadConfig() -> DebugSimulationConfig
  func saveConfig(_ config: DebugSimulationConfig)
}

final class DebugSimulationStore: DebugSimulationStoring {
  static let shared = DebugSimulationStore()

  private let defaults: UserDefaults

  private let enabledKey = "isitup.debug.simulation.enabled"
  private let latencyMsKey = "isitup.debug.simulation.additionalLatencyMs"
  private let defaultLatencyMs = 1200
  private let maxLatencyMs = 5000

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func loadConfig() -> DebugSimulationConfig {
    let storedLatency = defaults.object(forKey: latencyMsKey) as? Int
      ?? defaultLatencyMs
    let clampedLatency = max(0, min(maxLatencyMs, storedLatency))

    // Always start with simulation disabled on app launch to avoid stale test state.
    defaults.set(false, forKey: enabledKey)

    return DebugSimulationConfig(
      isEnabled: false,
      additionalLatencyMs: clampedLatency
    )
  }

  func saveConfig(_ config: DebugSimulationConfig) {
    defaults.set(config.isEnabled, forKey: enabledKey)
    let clampedLatency = max(0, min(maxLatencyMs, config.additionalLatencyMs))
    defaults.set(clampedLatency, forKey: latencyMsKey)
  }
}
