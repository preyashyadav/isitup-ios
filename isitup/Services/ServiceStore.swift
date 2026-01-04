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
    //Try UserDefaults first
    if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
       let saved = try? JSONDecoder().decode([ServiceConfig].self, from: data),
       !saved.isEmpty {
      return saved
    }

    //  else fall back to bundled
    guard let url = Bundle.main.url(forResource: "services", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let bundled = try? JSONDecoder().decode([ServiceConfig].self, from: data),
          !bundled.isEmpty
    else {
      return []
    }

    return bundled
  }

  func saveConfigs(_ configs: [ServiceConfig]) {
    guard let data = try? JSONEncoder().encode(configs) else { return }
    UserDefaults.standard.set(data, forKey: userDefaultsKey)
  }

  func resetToBundled() -> [ServiceConfig] {
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    return loadConfigs()
  }
}
