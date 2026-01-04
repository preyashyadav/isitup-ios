//
//  DashboardView.swift
//  isitup
//
//  Created by Preyash Yadav on 7/17/25.
//

import SwiftUI
import Charts

struct DashboardView: View {
  @ObservedObject var vm: HealthViewModel

  struct BarPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
  }

  var points: [BarPoint] {
    let s = vm.summary
    return [
      BarPoint(label: "Healthy", value: s.healthy),
      BarPoint(label: "Down", value: s.down),
      BarPoint(label: "Error", value: s.error),
      BarPoint(label: "Checking", value: s.checking),
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Dashboard")
          .font(.largeTitle.weight(.bold))

        Chart(points) { p in
          BarMark(
            x: .value("State", p.label),
            y: .value("Count", p.value)
          )
        }
        .frame(height: 220)

        Text("Tip: Run “Check All” a few times to generate history and see trends.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Divider()
          .padding(.top, 12)

        footer
      }
      .padding()
    }
  }

  private var footer: some View {
    HStack {
      Spacer()

      VStack(spacing: 4) {
        Text("Built by Preyash Yadav")
          .font(.caption)
          .foregroundStyle(.secondary)

        Link("preyashyadav.com",
             destination: URL(string: "https://preyashyadav.com")!)
          .font(.caption)
      }

      Spacer()
    }
    .padding(.top, 6)
  }
}

