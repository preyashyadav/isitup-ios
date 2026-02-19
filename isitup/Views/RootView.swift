//
//  RootView.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import SwiftUI

struct RootView: View {
  @StateObject private var vm: HealthViewModel
  @State private var unlocked: Bool

  @Environment(\.scenePhase) private var scenePhase

  init(useMock: Bool = true) {
    _vm = StateObject(wrappedValue: HealthViewModel(useMock: useMock))
    _unlocked = State(initialValue: PinStore.shared.isUnlocked())
  }

  var body: some View {
    Group {
      if shouldShowMainApp {
        mainApp
      } else {
        PinLockView {
          PinStore.shared.setUnlocked(true)
          unlocked = true
        }
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      // lock whenever - leave foreground
      if newPhase != .active {
        PinStore.shared.lock()
        unlocked = false
        return
      }

      //  active again, sync state from the store
      unlocked = PinStore.shared.isUnlocked()
    }
    .onReceive(NotificationCenter.default.publisher(for: NotificationManager.checkNowRequestedNotification)) { _ in
      Task { await vm.checkAll() }
    }
  }

  private var shouldShowMainApp: Bool {
    // no PIN set, no lock screen needed
    if !PinStore.shared.hasPin() { return true }
    return unlocked
  }

  private var mainApp: some View {
    TabView {
      MonitorView(vm: vm)
        .tabItem { Label("Monitor", systemImage: "waveform.path.ecg") }

      DashboardView(vm: vm)
        .tabItem { Label("Dashboard", systemImage: "chart.bar") }
    }
  }
}

#Preview {
  RootView(useMock: true)
}
