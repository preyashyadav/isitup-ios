//
//  ServicesSettingsView.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import SwiftUI

struct ServicesSettingsView: View {
  @ObservedObject var vm: HealthViewModel

  @State private var draft: [ServiceConfig] = []
  @State private var showEditor = false
  @State private var editIndex: Int? = nil

  // PIN settings
  @State private var showPinSheet = false
  @State private var pinMode: PinSettingsView.Mode = .setNew

  var body: some View {
    List {
      Section("Configured Services") {
        if draft.isEmpty {
          Text("No services yet. Tap “Add Service”.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(draft.enumerated()), id: \.offset) { idx, cfg in
            Button {
              editIndex = idx
              showEditor = true
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(displayName(for: cfg))
                  .font(.headline)
                Text(cfg.url)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
          .onDelete { indexSet in
            draft.remove(atOffsets: indexSet)
          }
        }
      }

      Section {
        Button {
          editIndex = nil
          showEditor = true
        } label: {
          Label("Add Service", systemImage: "plus")
        }

        Button("Reset to bundled defaults") {
          vm.resetConfigsToBundled()
          draft = vm.currentConfigs()
        }
        .foregroundStyle(.red)
      }

        Section("Notifications") {
          Toggle("Notify when a service is down", isOn: $vm.notifyOnDown)
            .onChange(of: vm.notifyOnDown) { _, newValue in
              if newValue {
                Task { _ = await NotificationManager.shared.requestAuthorizationIfNeeded() }
              }
            }
        }


      Section("Security") {
        if PinStore.shared.hasPin() {
          Button("Change PIN") {
            pinMode = .change
            showPinSheet = true
          }

          Button("Remove PIN") {
            pinMode = .remove
            showPinSheet = true
          }
          .foregroundStyle(.red)

          Button("Lock now") {
            PinStore.shared.lock()
          }
        } else {
          Button("Set PIN") {
            pinMode = .setNew
            showPinSheet = true
          }
        }
      }

      Section {
        Button("Save Changes") {
          let cleaned = draft
            .map {
              ServiceConfig(
                name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                url: $0.url.trimmingCharacters(in: .whitespacesAndNewlines)
              )
            }
            .filter { !$0.url.isEmpty }

          vm.saveConfigs(cleaned)
          draft = vm.currentConfigs()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!hasAnyValidURL(draft))
      }
    }
    .navigationTitle("Edit Services")
    .onAppear { draft = vm.currentConfigs() }

    //  editor sheet
    .sheet(isPresented: $showEditor, onDismiss: cleanupNewPlaceholderIfNeeded) {
      ServiceEditorSheet(
        config: bindingForEdit(),
        onCancel: { showEditor = false },
        onDone: { updated in
          applyUpdatedConfig(updated)
          showEditor = false
        }
      )
      .presentationDetents([.medium])
    }

    // PIN sheet
    .sheet(isPresented: $showPinSheet) {
      PinSettingsView(mode: pinMode) {
        // RootView will enforce lock state on background/foreground or relaunch
      }
      .presentationDetents([.medium])
    }
  }

  private func displayName(for cfg: ServiceConfig) -> String {
    let trimmed = cfg.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled" : trimmed
  }

  private func hasAnyValidURL(_ configs: [ServiceConfig]) -> Bool {
    configs.contains { isValidURL($0.url) }
  }

  private func isValidURL(_ s: String) -> Bool {
    guard let u = URL(string: s), let scheme = u.scheme, let host = u.host else { return false }
    return (scheme == "https" || scheme == "http") && !host.isEmpty
  }

  private func bindingForEdit() -> Binding<ServiceConfig> {
    if let idx = editIndex {
      return Binding(get: { draft[idx] }, set: { draft[idx] = $0 })
    } else {
      draft.append(ServiceConfig(name: "", url: "https://"))
      let idx = draft.count - 1
      editIndex = idx
      return Binding(get: { draft[idx] }, set: { draft[idx] = $0 })
    }
  }

  private func applyUpdatedConfig(_ updated: ServiceConfig) {
    guard let idx = editIndex else { return }
    let cleaned = ServiceConfig(
      name: updated.name.trimmingCharacters(in: .whitespacesAndNewlines),
      url: updated.url.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    draft[idx] = cleaned
    editIndex = nil
  }

  private func cleanupNewPlaceholderIfNeeded() {
    if let idx = editIndex, idx < draft.count {
      let cfg = draft[idx]
      if cfg.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
          !isValidURL(cfg.url) {
        draft.remove(at: idx)
      }
    }
    editIndex = nil
  }
}

