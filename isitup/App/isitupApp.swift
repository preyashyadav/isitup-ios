//
//  isitupApp.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import SwiftUI
import UserNotifications
import AppIntents

@main
struct isitupApp: App {
  private let notifDelegate = NotificationDelegate()

  init() {
    NotificationManager.shared.registerCategories()
    UNUserNotificationCenter.current().delegate = notifDelegate
    if #available(iOS 16.0, *) {
      Task {
        await refreshAppShortcuts()
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView(useMock: false)
    }
  }
}

@MainActor
@available(iOS 16.0, *)
private func refreshAppShortcuts() async {
  if #available(iOS 17.2, *) {
    ServiceShortcutsProvider.updateAppShortcutParameters()
  }
}
