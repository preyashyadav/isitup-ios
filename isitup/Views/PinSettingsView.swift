//
//  PinSettingsView.swift
//  isitup
//
//  Created by Preyash Yadav on 8/9/25.
//

import SwiftUI

struct PinSettingsView: View {
  @Environment(\.dismiss) private var dismiss

  enum Mode {
    case setNew
    case change
    case remove
  }

  let mode: Mode
  let onCompleted: () -> Void

  @State private var currentPin: String = ""
  @State private var newPin: String = ""
  @State private var confirmPin: String = ""
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        if needsCurrentPin {
          Section("Current PIN") {
            SecureField("4-digit PIN", text: $currentPin)
              .keyboardType(.numberPad)
              .textContentType(.oneTimeCode)
              .onChange(of: currentPin) { _, v in currentPin = sanitize(v) }
          }
        }

        if needsNewPin {
          Section(mode == .setNew ? "Set PIN" : "New PIN") {
            SecureField("New 4-digit PIN", text: $newPin)
              .keyboardType(.numberPad)
              .textContentType(.oneTimeCode)
              .onChange(of: newPin) { _, v in newPin = sanitize(v) }

            SecureField("Confirm new PIN", text: $confirmPin)
              .keyboardType(.numberPad)
              .textContentType(.oneTimeCode)
              .onChange(of: confirmPin) { _, v in confirmPin = sanitize(v) }
          }
        }

        if let error {
          Section {
            Text(error)
              .foregroundStyle(.red)
              .font(.caption)
          }
        }
      }
      .navigationTitle(title)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(actionTitle) { submit() }
            .disabled(!canSubmit)
        }
      }
    }
  }

  private var needsCurrentPin: Bool {
    switch mode {
    case .setNew: return false
    case .change, .remove: return true
    }
  }

  private var needsNewPin: Bool {
    switch mode {
    case .setNew, .change: return true
    case .remove: return false
    }
  }

  private var title: String {
    switch mode {
    case .setNew: return "Set PIN"
    case .change: return "Change PIN"
    case .remove: return "Remove PIN"
    }
  }

  private var actionTitle: String {
    switch mode {
    case .setNew: return "Save"
    case .change: return "Update"
    case .remove: return "Remove"
    }
  }

  private var canSubmit: Bool {
    switch mode {
    case .setNew:
      return newPin.count == 4 && newPin == confirmPin
    case .change:
      return currentPin.count == 4 && newPin.count == 4 && newPin == confirmPin
    case .remove:
      return currentPin.count == 4
    }
  }

  private func submit() {
    error = nil

    switch mode {
    case .setNew:
      PinStore.shared.setPin(newPin)
      PinStore.shared.lock()
      onCompleted()
      dismiss()

    case .change:
      let ok = PinStore.shared.changePin(current: currentPin, new: newPin)
      if ok {
        PinStore.shared.lock()
        onCompleted()
        dismiss()
      } else {
        error = "Current PIN is incorrect."
        currentPin = ""
      }

    case .remove:
      let ok = PinStore.shared.removePin(current: currentPin)
      if ok {
        onCompleted()
        dismiss()
      } else {
        error = "Current PIN is incorrect."
        currentPin = ""
      }
    }
  }

  private func sanitize(_ s: String) -> String {
    String(s.filter { $0.isNumber }.prefix(4))
  }
}

