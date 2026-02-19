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
        .navigationTitle("isitup v1.2")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
              ServicesSettingsView(vm: vm)
            } label: {
              Image(systemName: "gear")
            }
            .accessibilityLabel("Settings")
          }

          ToolbarItem(placement: .topBarTrailing) {
            Button("Check All") { Task { await vm.checkAll() } }
              .disabled(vm.services.isEmpty)
          }
        }
        .navigationDestination(for: UUID.self) { id in
          ServiceDetailView(vm: vm, serviceId: id)
        }
        .task {
          await vm.refreshDailyDigestIfNeeded()
        }
    }
  }
}

private struct ServiceListContents: View {
  @ObservedObject var vm: HealthViewModel

  var body: some View {
    List {
      if vm.isDigestFeatureAvailable {
        Section {
          DailyDigestCard(
            digest: vm.dailyDigest,
            generatedAt: vm.dailyDigestGeneratedAt,
            isGenerating: vm.isGeneratingDigest,
            onGenerate: {
              Task { await vm.refreshDailyDigestIfNeeded(force: true) }
            }
          )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
      }

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

private struct DailyDigestCard: View {
  let digest: String?
  let generatedAt: Date?
  let isGenerating: Bool
  let onGenerate: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Daily Digest")
          .font(.headline)

        Spacer()

        Text("Generated on-device")
          .font(.caption2.weight(.semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.blue.opacity(0.14))
          .clipShape(Capsule())
      }

      if let digest, !digest.isEmpty {
        Text(digest)
          .font(.subheadline)
          .foregroundStyle(.primary)
      } else {
        Text("No digest yet. Generate a summary from recent service checks.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        if let generatedAt {
          Text("Updated \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Button {
          onGenerate()
        } label: {
          Text(isGenerating ? "Generating..." : "Generate Summary")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background((isGenerating ? Color.gray : Color.accentColor).opacity(0.95))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.75 : 1.0)
      }
    }
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding(.vertical, 6)
    .padding(.horizontal, 6)
  }
}
