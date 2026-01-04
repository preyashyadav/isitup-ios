//
//  NotificationManager.swift
//  isitup
//
//  Created by Preyash Yadav on 9/3/25.
//

import Foundation
import UserNotifications

final class NotificationManager {
  static let shared = NotificationManager()
  private init() {}

  // MARK: - Config

  private let downCategoryId = "SERVICE_DOWN"
  private let openAppActionId = "OPEN_APP"

  /// avoid notif spam
  private let cooldownSeconds: TimeInterval = 60

  private var lastNotified: [String: Date] = [:]

  // MARK: - Public

  ///at app startup
  func registerCategories() {
    let openAction = UNNotificationAction(
      identifier: openAppActionId,
      title: "Open App",
      options: [.foreground]
    )

    let category = UNNotificationCategory(
      identifier: downCategoryId,
      actions: [openAction],
      intentIdentifiers: [],
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  func requestAuthorizationIfNeeded() async -> Bool {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()

    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return true
    case .notDetermined:
      do {
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
      } catch {
        return false
      }
    case .denied:
      return false
    @unknown default:
      return false
    }
  }

  func notifyServiceDown(name: String, url: String, detail: String?) async {
    // TODO: avoid repeat notifications in a short window
    let key = "\(name)|\(url)"
    let now = Date()
    if let last = lastNotified[key], now.timeIntervalSince(last) < cooldownSeconds {
      return
    }
    lastNotified[key] = now

    let ok = await requestAuthorizationIfNeeded()
    guard ok else { return }

    let content = UNMutableNotificationContent()
    content.title = "Service down: \(name)"
    content.body = [url, detail].compactMap { $0 }.joined(separator: " • ")
    content.sound = .default
    content.categoryIdentifier = downCategoryId

    // fire immediately
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let req = UNNotificationRequest(
      identifier: "down.\(name).\(UUID().uuidString)",
      content: content,
      trigger: trigger
    )

    do {
      try await UNUserNotificationCenter.current().add(req)
    } catch {
      // ignore
    }
  }
}

