//
//  MonitorView.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation
import SwiftUI

struct MonitorView: View {
  @ObservedObject var vm: HealthViewModel

  var body: some View {
    NavigationStack {
      ServiceListContents(vm: vm)
        .navigationTitle("isitup v1.0")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
              ServicesSettingsView(vm: vm)
            } label: {
              Image(systemName: "gear")
            }
            .accessibilityLabel("Edit Services")
          }

          ToolbarItem(placement: .topBarTrailing) {
            Button("Check All") { Task { await vm.checkAll() } }
              .disabled(vm.services.isEmpty)
          }
        }
        .navigationDestination(for: UUID.self) { id in
          ServiceDetailView(vm: vm, serviceId: id)
        }
    }
  }
}

private struct ServiceListContents: View {
  @ObservedObject var vm: HealthViewModel

  var body: some View {
    List {
      Section {
        SummaryCard(summary: vm.summary)
      }
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)

      Section("Services") {
        if vm.services.isEmpty {
          Text("No services configured. Tap the gear icon to add some.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(vm.services) { s in
            NavigationLink(value: s.id) {
              ServiceRow(service: s)
            }
          }
        }
      }
    }
  }
}

