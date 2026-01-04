//
//  PinStore.swift
//  isitup
//
//  Created by Preyash Yadav on 8/7/25.
//

import Foundation

final class PinStore {
  static let shared = PinStore()
  private init() {}

  private let pinKey = "isitup.pin"
  private let unlockedKey = "isitup.unlocked"

  func hasPin() -> Bool {
    UserDefaults.standard.string(forKey: pinKey) != nil
  }

  func setPin(_ pin: String) {
    UserDefaults.standard.set(pin, forKey: pinKey)
    setUnlocked(false)
  }

  func verifyPin(_ pin: String) -> Bool {
    let saved = UserDefaults.standard.string(forKey: pinKey)
    return saved == pin
  }

  func changePin(current: String, new: String) -> Bool {
    guard verifyPin(current) else { return false }
    setPin(new)
    return true
  }

  func removePin(current: String) -> Bool {
    guard verifyPin(current) else { return false }
    UserDefaults.standard.removeObject(forKey: pinKey)
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
}
