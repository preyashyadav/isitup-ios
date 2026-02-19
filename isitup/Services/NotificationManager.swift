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

  static let checkNowActionIdentifier = "CHECK_NOW"
  static let checkNowRequestedNotification = Notification.Name("isitup.notification.checkNowRequested")

  private init() {
    loadPersistedCooldowns()
  }

  // MARK: - Config

  private let downCategoryId = "SERVICE_DOWN"
  private let groupOutageCategoryId = "GROUP_OUTAGE"
  private let openAppActionId = "OPEN_APP"
  private let checkNowActionId = NotificationManager.checkNowActionIdentifier

  /// avoid notif spam
  private let cooldownSeconds: TimeInterval = 60

  private var lastNotified: [String: Date] = [:]
  private let lastNotifiedPrefix = "isitup.lastNotified."

  // MARK: - Public

  ///at app startup
  func registerCategories() {
    let openAction = UNNotificationAction(
      identifier: openAppActionId,
      title: "Open App",
      options: [.foreground]
    )

    let checkNowAction = UNNotificationAction(
      identifier: checkNowActionId,
      title: "Check Now",
      options: [.foreground]
    )

    let downCategory = UNNotificationCategory(
      identifier: downCategoryId,
      actions: [openAction],
      intentIdentifiers: [],
      options: []
    )

    let groupedCategory = UNNotificationCategory(
      identifier: groupOutageCategoryId,
      actions: [checkNowAction, openAction],
      intentIdentifiers: [],
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([downCategory, groupedCategory])
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

  func notifyServiceDown(serviceID: String, name: String, url: String, detail: String?) async {
    await notify(
      cooldownKey: serviceID,
      requestIDPrefix: "down",
      title: "Service down: \(name)",
      bodyParts: [url, detail]
    )
  }

  func notifyServiceDegrading(serviceID: String, name: String, url: String, detail: String?) async {
    await notify(
      cooldownKey: "\(serviceID).degrading",
      requestIDPrefix: "degrading",
      title: "Service degrading: \(name)",
      bodyParts: [url, detail]
    )
  }

  func notifyGroupedOutage(serviceNames: [String]) async {
    let normalized = serviceNames
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !normalized.isEmpty else { return }

    let previewNames = normalized.prefix(4).joined(separator: ", ")
    let extra = normalized.count > 4 ? ", +\(normalized.count - 4) more" : ""
    let body = "Possible outage - \(normalized.count) services affected: \(previewNames)\(extra)"

    await notify(
      cooldownKey: "groupedOutage",
      requestIDPrefix: "grouped",
      title: "Possible outage",
      bodyParts: [body],
      categoryIdentifier: groupOutageCategoryId
    )
  }

  func notifyGroupedDegrading(serviceNames: [String]) async {
    let normalized = serviceNames
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !normalized.isEmpty else { return }

    let previewNames = normalized.prefix(4).joined(separator: ", ")
    let extra = normalized.count > 4 ? ", +\(normalized.count - 4) more" : ""
    let body = "Latency issues - \(normalized.count) services degrading: \(previewNames)\(extra)"

    await notify(
      cooldownKey: "groupedDegrading",
      requestIDPrefix: "groupedDegrading",
      title: "Performance degrading",
      bodyParts: [body],
      categoryIdentifier: groupOutageCategoryId
    )
  }

  private func notify(
    cooldownKey: String,
    requestIDPrefix: String,
    title: String,
    bodyParts: [String?],
    categoryIdentifier: String? = nil
  ) async {
    let now = Date()
    if let last = lastNotified[cooldownKey], now.timeIntervalSince(last) < cooldownSeconds {
      return
    }
    lastNotified[cooldownKey] = now
    persistCooldown(date: now, for: cooldownKey)

    let ok = await requestAuthorizationIfNeeded()
    guard ok else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = bodyParts.compactMap { $0 }.joined(separator: " • ")
    content.sound = .default
    content.categoryIdentifier = categoryIdentifier ?? downCategoryId

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let req = UNNotificationRequest(
      identifier: "\(requestIDPrefix).\(UUID().uuidString)",
      content: content,
      trigger: trigger
    )

    do {
      try await UNUserNotificationCenter.current().add(req)
    } catch {
      // ignore
    }
  }

  private func loadPersistedCooldowns() {
    let all = UserDefaults.standard.dictionaryRepresentation()

    for (key, value) in all where key.hasPrefix(lastNotifiedPrefix) {
      let serviceID = String(key.dropFirst(lastNotifiedPrefix.count))
      if serviceID.isEmpty { continue }

      if let seconds = value as? TimeInterval {
        lastNotified[serviceID] = Date(timeIntervalSince1970: seconds)
      } else if let date = value as? Date {
        lastNotified[serviceID] = date
      }
    }
  }

  private func persistCooldown(date: Date, for serviceID: String) {
    let key = "\(lastNotifiedPrefix)\(serviceID)"
    UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
  }
}
