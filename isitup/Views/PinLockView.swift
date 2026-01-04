//
//  PinLockView.swift
//  isitup
//
//  Created by Preyash Yadav on 8/7/25.
//

import SwiftUI

struct PinLockView: View {
  let onUnlock: () -> Void

  @State private var pinInput: String = ""
  @State private var error: String?

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Text("Enter PIN")
        .font(.largeTitle.weight(.bold))

      SecureField("4-digit PIN", text: $pinInput)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .multilineTextAlignment(.center)
        .font(.title2)
        .frame(width: 180)
        .onChange(of: pinInput) { _, newValue in
          let sanitized = sanitizePin(newValue)
          if sanitized != pinInput {
            pinInput = sanitized
          }
          if error != nil, !sanitized.isEmpty {
            error = nil
          }
        }

      if let error {
        Text(error)
          .foregroundStyle(.red)
          .font(.caption)
      }

      Button("Unlock") {
        attemptUnlock()
      }
      .buttonStyle(.borderedProminent)
      .disabled(pinInput.count != 4)

      Spacer()
    }
    .padding()
  }

  private func attemptUnlock() {
    guard pinInput.count == 4 else { return }

    if PinStore.shared.verifyPin(pinInput) {
      PinStore.shared.setUnlocked(true)
      onUnlock()
    } else {
      error = "Incorrect PIN"
      pinInput = ""
    }
  }

  private func sanitizePin(_ s: String) -> String {
    let digitsOnly = s.filter { $0.isNumber }
    return String(digitsOnly.prefix(4))
  }
}

#Preview {
  PinLockView(onUnlock: {})
}

