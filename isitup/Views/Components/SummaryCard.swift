//
//  SummaryCard.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation
import SwiftUI

struct SummaryCard: View {
  let summary: HealthSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Overview")
        .font(.headline)

      HStack(spacing: 12) {
        SummaryPill(label: "Total", value: summary.total)
        SummaryPill(label: "Healthy", value: summary.healthy)
        SummaryPill(label: "Down", value: summary.down)
        SummaryPill(label: "Error", value: summary.error)
      }
    }
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding(.vertical, 6)
    .padding(.horizontal, 6)
  }
}

struct SummaryPill: View {
  let label: String
  let value: Int

  var body: some View {
    VStack(spacing: 4) {
      Text("\(value)").font(.headline)
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
    .frame(minWidth: 62)
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .background(Color.gray.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
