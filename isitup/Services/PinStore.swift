//
//  PinStore.swift
//  isitup
//
//  Created by Preyash Yadav on 8/7/25.
//

import Foundation
import Security

final class PinStore {
  static let shared = PinStore()
  private init() {
    migrateLegacyPinIfNeeded()
  }

  private let pinService = "com.isitup.pin"
  private let pinAccount = "default"
  private let legacyPinKey = "isitup.pin"
  private let unlockedKey = "isitup.unlocked"

  func hasPin() -> Bool {
    readPin() != nil
  }

  func setPin(_ pin: String) {
    guard savePin(pin) else {
      lock()
      return
    }
    setUnlocked(false)
  }

  func verifyPin(_ pin: String) -> Bool {
    guard let saved = readPin() else { return false }
    return saved == pin
  }

  func changePin(current: String, new: String) -> Bool {
    guard verifyPin(current) else { return false }
    setPin(new)
    return true
  }

  func removePin(current: String) -> Bool {
    guard verifyPin(current) else { return false }
    guard deletePin() else {
      lock()
      return false
    }
    setUnlocked(false)
    return true
  }

  func isUnlocked() -> Bool {
    UserDefaults.standard.bool(forKey: unlockedKey)
  }

  func setUnlocked(_ unlocked: Bool) {
    UserDefaults.standard.set(unlocked, forKey: unlockedKey)
  }

  func lock() {
    setUnlocked(false)
  }

  private func keychainQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: pinService,
      kSecAttrAccount as String: pinAccount
    ]
  }

  private func readPin() -> String? {
    var query = keychainQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data,
            let pin = String(data: data, encoding: .utf8) else {
        lock()
        return nil
      }
      return pin
    case errSecItemNotFound:
      return nil
    default:
      lock()
      return nil
    }
  }

  private func savePin(_ pin: String) -> Bool {
    let data = Data(pin.utf8)
    let query = keychainQuery()
    let update: [String: Any] = [kSecValueData as String: data]

    let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if updateStatus == errSecSuccess {
      return true
    }

    if updateStatus == errSecItemNotFound {
      var add = query
      add[kSecValueData as String] = data
      let addStatus = SecItemAdd(add as CFDictionary, nil)
      return addStatus == errSecSuccess
    }

    return false
  }

  private func deletePin() -> Bool {
    let status = SecItemDelete(keychainQuery() as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }

  private func migrateLegacyPinIfNeeded() {
    guard readPin() == nil else {
      UserDefaults.standard.removeObject(forKey: legacyPinKey)
      return
    }

    guard let legacyPin = UserDefaults.standard.string(forKey: legacyPinKey), !legacyPin.isEmpty else {
      return
    }

    if savePin(legacyPin) {
      UserDefaults.standard.removeObject(forKey: legacyPinKey)
      lock()
    } else {
      lock()
    }
  }
}
