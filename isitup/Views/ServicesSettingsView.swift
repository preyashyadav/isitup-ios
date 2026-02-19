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
  @State private var editorContext: EditorContext? = nil

  // PIN settings
  @State private var showPinSheet = false
  @State private var pinMode: PinSettingsView.Mode = .setNew
  @State private var showClearHistoryConfirm = false

  private struct EditorContext: Identifiable {
    let id = UUID()
    let index: Int
  }

  var body: some View {
    List {
      Section("Service Management") {
        if draft.isEmpty {
          Text("No services yet. Tap “Add Service”.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(draft.enumerated()), id: \.offset) { idx, cfg in
            Button {
              editorContext = EditorContext(index: idx)
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

        Button {
          draft.append(ServiceConfig(name: "", url: "https://"))
          editorContext = EditorContext(index: draft.count - 1)
        } label: {
          Label("Add Service", systemImage: "plus")
        }

        Button("Reset to bundled defaults") {
          vm.resetConfigsToBundled()
          draft = vm.currentConfigs()
        }
        .foregroundStyle(.red)

        Button("Save Service List") {
          let cleaned = draft
            .map {
              ServiceConfig(
                id: $0.id,
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

        Text("This only saves service list edits. Security, history, and debug settings apply immediately.")
          .font(.caption)
          .foregroundStyle(.secondary)
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

      Section("History") {
        Button("Clear check history") {
          showClearHistoryConfirm = true
        }
        .foregroundStyle(.red)

        Text("Removes stored samples and cached daily digest, then resets service status to unknown.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

#if DEBUG
      Section("Developer Tools (Debug)") {
        Toggle("Enable simulated latency", isOn: $vm.debugSimulationEnabled)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Added latency")
            Spacer()
            Text("\(Int(vm.debugAdditionalLatencyMs.rounded())) ms")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }

          Slider(value: $vm.debugAdditionalLatencyMs, in: 0...5000, step: 100)
            .disabled(!vm.debugSimulationEnabled)
        }

        Text("Adds an artificial delay to each check so degrading behavior can be tested without changing real services. Applies immediately (no Save Changes needed). Requires at least 10 latency samples per healthy service.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
#endif
    }
    .navigationTitle("Settings")
    .onAppear { draft = vm.currentConfigs() }

    //  editor sheet
    .sheet(item: $editorContext) { context in
      ServiceEditorSheet(
        config: bindingForEdit(index: context.index),
        onCancel: {
          removePlaceholderIfNeeded(at: context.index)
          editorContext = nil
        },
        onDone: { updated in
          applyUpdatedConfig(updated, at: context.index)
          editorContext = nil
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
    .alert("Clear History?", isPresented: $showClearHistoryConfirm) {
      Button("Cancel", role: .cancel) { }
      Button("Clear", role: .destructive) {
        vm.clearHistory()
      }
    } message: {
      Text("This will remove all saved check samples and the cached daily digest.")
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

  private func bindingForEdit(index: Int) -> Binding<ServiceConfig> {
    if draft.indices.contains(index) {
      return Binding(get: { draft[index] }, set: { draft[index] = $0 })
    }

    return .constant(ServiceConfig(name: "", url: "https://"))
  }

  private func applyUpdatedConfig(_ updated: ServiceConfig, at index: Int) {
    guard draft.indices.contains(index) else { return }
    let cleaned = ServiceConfig(
      id: updated.id,
      name: updated.name.trimmingCharacters(in: .whitespacesAndNewlines),
      url: updated.url.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    draft[index] = cleaned
  }

  private func removePlaceholderIfNeeded(at index: Int) {
    guard draft.indices.contains(index) else { return }
    let cfg = draft[index]
    if cfg.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isValidURL(cfg.url) {
      draft.remove(at: index)
    }
  }
}
