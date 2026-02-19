//
//  NotificationDelegate.swift
//  isitup
//
//  Created by Preyash Yadav on 9/3/25.
//

import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // banner + sound (app open)
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == NotificationManager.checkNowActionIdentifier {
      NotificationCenter.default.post(name: NotificationManager.checkNowRequestedNotification, object: nil)
    }
    completionHandler()
  }
}
