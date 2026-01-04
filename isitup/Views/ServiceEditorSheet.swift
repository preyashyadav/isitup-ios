//
//  ServiceEditorSheet.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation
import SwiftUI

struct ServiceEditorSheet: View {
  @Binding var config: ServiceConfig

  let onCancel: () -> Void
  let onDone: (ServiceConfig) -> Void

  @State private var name: String = ""
  @State private var url: String = ""
  @State private var showInvalidHint: Bool = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Service") {
          TextField("Name", text: $name)

          TextField("URL (https://...)", text: $url)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
        }

        if showInvalidHint && !isValidURL(url) {
          Text("Please enter a valid http(s) URL (e.g., https://apple.com).")
            .foregroundStyle(.orange)
            .font(.caption)
        }
      }
      .navigationTitle("Service")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { onCancel() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

            guard isValidURL(trimmedURL) else {
              showInvalidHint = true
              return
            }

            let updated = ServiceConfig(
              name: trimmedName.isEmpty ? "Untitled" : trimmedName,
              url: trimmedURL
            )
            config = updated
            onDone(updated)
          }
        }
      }
      .onAppear {
        name = config.name
        url = config.url
      }
    }
  }

  private func isValidURL(_ s: String) -> Bool {
    guard let u = URL(string: s), let scheme = u.scheme, let host = u.host else { return false }
    return (scheme == "https" || scheme == "http") && !host.isEmpty
  }
}
