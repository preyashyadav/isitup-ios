//
//  ServiceDetailView.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation
import SwiftUI

struct ServiceDetailView: View {
  @ObservedObject var vm: HealthViewModel
  let serviceId: UUID

  private var service: ServiceStatus? {
    vm.services.first(where: { $0.id == serviceId })
  }

  var body: some View {
    Group {
      if let s = service {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text(s.name)
              .font(.title2.weight(.bold))
            Spacer()
            StatusBadge(state: s.state)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Endpoint").font(.headline)
            Text(s.endpoint?.absoluteString ?? "—")
              .font(.caption)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Last Checked").font(.headline)
            Text(s.lastCheckedLabel)
              .foregroundStyle(.secondary)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Latency Samples").font(.headline)
            Text("Healthy samples: \(healthyLatencySamplesCount(for: s))")
              .foregroundStyle(.secondary)
            Text("Non-simulated baseline: \(nonSimulatedHealthySamplesCount(for: s))")
              .foregroundStyle(.secondary)
            Text("Latest latency: \(latestLatencyLabel(for: s))")
              .foregroundStyle(.secondary)
          }

          if let msg = s.message, !msg.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Message").font(.headline)
              Text(msg).foregroundStyle(.secondary)
            }
          }

          Spacer()

          Button {
            Task { await vm.check(serviceId: serviceId) }
          } label: {
            HStack {
              Spacer()
              Text("Check Now").font(.headline)
              Spacer()
            }
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()
      } else {
        Text("Service not found.")
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Details")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func healthyLatencySamplesCount(for service: ServiceStatus) -> Int {
    service.samples.filter { ($0.state == .healthy || $0.state == .degrading) && $0.responseTimeMs != nil }.count
  }

  private func nonSimulatedHealthySamplesCount(for service: ServiceStatus) -> Int {
    service.samples.filter {
      ($0.state == .healthy || $0.state == .degrading)
      && $0.responseTimeMs != nil
      && $0.isSimulated != true
    }.count
  }

  private func latestLatencyLabel(for service: ServiceStatus) -> String {
    guard let latest = service.samples.compactMap(\.responseTimeMs).last else {
      return "—"
    }
    return "\(latest) ms"
  }
}
