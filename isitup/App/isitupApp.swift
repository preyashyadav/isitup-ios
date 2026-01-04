//
//  isitupApp.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import SwiftUI
import UserNotifications

@main
struct isitupApp: App {
  private let notifDelegate = NotificationDelegate()

  init() {
    NotificationManager.shared.registerCategories()
    UNUserNotificationCenter.current().delegate = notifDelegate
  }

  var body: some Scene {
    WindowGroup {
      RootView(useMock: false)
    }
  }
}
