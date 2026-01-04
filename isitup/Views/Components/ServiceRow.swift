//
//  ServiceRow.swift
//  isitup
//
//  Created by Preyash Yadav on 7/16/25.
//

import Foundation
import SwiftUI

struct ServiceRow: View {
  let service: ServiceStatus

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(service.name)
          .font(.headline)

        Text("Last checked: \(service.lastCheckedLabel)")
          .font(.caption)
          .foregroundStyle(.secondary)

        if let msg = service.message, !msg.isEmpty {
          Text(msg)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()
      StatusBadge(state: service.state)
    }
    .padding(.vertical, 6)
  }
}
