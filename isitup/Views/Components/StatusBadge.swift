//
//  StatusBadge.swift
//  isitup
//
//  Created by Preyash Yadav on 7/16/25.
//

import Foundation
import SwiftUI

struct StatusBadge: View {
  let state: HealthState

  var body: some View {
    Text(label)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(background)
      .clipShape(Capsule())
  }

  private var label: String {
    switch state {
    case .unknown: return "UNKNOWN"
    case .checking: return "CHECKING"
    case .healthy: return "HEALTHY"
    case .degrading: return "DEGRADING"
    case .down: return "DOWN"
    case .error: return "ERROR"
    }
  }

  private var background: Color {
    switch state {
    case .unknown: return .gray.opacity(0.25)
    case .checking: return .blue.opacity(0.25)
    case .healthy: return .green.opacity(0.25)
    case .degrading: return .yellow.opacity(0.30)
    case .down: return .red.opacity(0.25)
    case .error: return .orange.opacity(0.25)
    }
  }
}
