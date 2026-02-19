//
//  ServiceStore.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation

final class ServiceStore {
  static let shared = ServiceStore()
  private init() {}

  private let userDefaultsKey = "isitup.services.config"

  func loadConfigs() -> [ServiceConfig] {
    // Try UserDefaults first.
    if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
       let saved = try? JSONDecoder().decode([ServiceConfig].self, from: data),
       !saved.isEmpty {
      let normalized = normalizeIDs(in: saved)
      if normalized != saved {
        saveConfigs(normalized)
      }
      return normalized
    }

    // Else fall back to bundled and persist a normalized copy.
    guard let url = Bundle.main.url(forResource: "services", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let bundled = try? JSONDecoder().decode([ServiceConfig].self, from: data),
          !bundled.isEmpty
    else {
      return []
    }

    let normalized = normalizeIDs(in: bundled)
    saveConfigs(normalized)
    return normalized
  }

  func saveConfigs(_ configs: [ServiceConfig]) {
    guard let data = try? JSONEncoder().encode(configs) else { return }
    UserDefaults.standard.set(data, forKey: userDefaultsKey)
  }

  func resetToBundled() -> [ServiceConfig] {
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    return loadConfigs()
  }

  private func normalizeIDs(in configs: [ServiceConfig]) -> [ServiceConfig] {
    var seen = Set<String>()

    return configs.map { cfg in
      var normalized = cfg
      let trimmed = normalized.id.trimmingCharacters(in: .whitespacesAndNewlines)
      let validAndUnique = UUID(uuidString: trimmed) != nil && !seen.contains(trimmed)

      if validAndUnique {
        normalized.id = trimmed
      } else {
        normalized.id = UUID().uuidString
      }

      seen.insert(normalized.id)
      return normalized
    }
  }
}
