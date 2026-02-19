//
//  ServiceIntents.swift
//  isitup
//
//  Created by Preyash Yadav on 2/19/26.
//

import Foundation
import AppIntents

@available(iOS 17.2, *)
struct CheckAllServicesIntent: AppIntent {
  static let title: LocalizedStringResource = "Check My Services"
  static let description = IntentDescription("Checks all monitored services and returns a status summary")
  static let openAppWhenRun = false

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let vm = await MainActor.run { HealthViewModel(useMock: false) }
    await vm.checkAll()
    let services = await MainActor.run { vm.services }

    let summary = await MainActor.run {
      ServiceIntentFormatter.checkAllSummary(services: services)
    }
    return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
  }
}

@available(iOS 16.0, *)
struct CheckServiceIntent: AppIntent {
  static let title: LocalizedStringResource = "Check Service"
  static let description = IntentDescription("Checks one or more monitored services matching the provided name")
  static let openAppWhenRun = false

  @Parameter(title: "Service", requestValueDialog: "Which service?")
  var serviceName: String

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let vm = await MainActor.run { HealthViewModel(useMock: false) }
    let initialServices = await MainActor.run { vm.services }

    let bestMatchID = await MainActor.run {
      ServiceIntentFormatter.bestMatchingServiceID(
        query: serviceName,
        in: initialServices
      )
    }

    guard let bestMatchID else {
      let msg = "No service found matching \"\(serviceName)\""
      return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
    }

    let currentService = await MainActor.run {
      vm.services.first(where: { $0.id == bestMatchID })
    }

    guard let currentService else {
      let msg = "No service found matching \"\(serviceName)\""
      return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
    }

    await vm.check(serviceId: bestMatchID)

    let checkedService = await MainActor.run {
      vm.services.first(where: { $0.id == bestMatchID })
    }

    let message = await MainActor.run {
      ServiceIntentFormatter.singleServiceSummary(service: checkedService ?? currentService)
    }
    return .result(value: message, dialog: IntentDialog(stringLiteral: message))
  }
}

@available(iOS 17.2, *)
struct ServiceShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CheckAllServicesIntent(),
      phrases: [
        "Check my services in \(.applicationName)",
        "Run service checks in \(.applicationName)",
        "Check status of my services in \(.applicationName)"
      ],
      shortTitle: "Check Services",
      systemImageName: "waveform.path.ecg"
    )
    AppShortcut(
      intent: CheckServiceIntent(),
      phrases: [
        "Check service in \(.applicationName)",
        "Check service and \(.applicationName)",
        "Ask \(.applicationName) to check a service",
        "Run single service check in \(.applicationName)"
      ],
      shortTitle: "Check Service",
      systemImageName: "dot.scope"
    )
  }
}

private enum ServiceIntentFormatter {
  static func checkAllSummary(services: [ServiceStatus]) -> String {
    let total = services.count
    let healthy = services.filter { $0.state == .healthy }.count
    let degrading = services.filter { $0.state == .degrading }.count
    let issues = services.filter { $0.state == .down || $0.state == .error }

    if issues.isEmpty, degrading == 0 {
      return "\(total) services checked. \(healthy) healthy, 0 down."
    }

    let issueNames = issues
      .map { displayName(for: $0) }
      .joined(separator: ", ")

    if issues.isEmpty {
      return "\(total) services checked. \(healthy) healthy, \(degrading) degrading."
    }

    return "\(total) services checked. \(healthy) healthy, \(degrading) degrading, \(issues.count) down: \(issueNames)"
  }

  static func bestMatchingServiceID(query: String, in services: [ServiceStatus]) -> UUID? {
    let needle = normalize(query)
    guard !needle.isEmpty else { return nil }

    if let exactName = services.first(where: { normalize($0.name) == needle }) {
      return exactName.id
    }
    if let exactHost = services.first(where: { normalize($0.endpoint?.host ?? "") == needle }) {
      return exactHost.id
    }
    if let partialName = services.first(where: { normalize($0.name).contains(needle) }) {
      return partialName.id
    }
    if let partialHost = services.first(where: { normalize($0.endpoint?.host ?? "").contains(needle) }) {
      return partialHost.id
    }
    return nil
  }

  static func singleServiceSummary(service: ServiceStatus) -> String {
    "\(service.name): \(stateLabel(for: service.state))\(messageSuffix(for: service))"
  }

  static func stateLabel(for state: HealthState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .checking: return "checking"
    case .healthy: return "healthy"
    case .degrading: return "degrading"
    case .down: return "down"
    case .error: return "error"
    }
  }

  static func messageSuffix(for service: ServiceStatus) -> String {
    guard let message = service.message, !message.isEmpty else { return "" }
    return " (\(message))"
  }

  static func displayName(for service: ServiceStatus) -> String {
    if let host = service.endpoint?.host, !host.isEmpty {
      return host
    }
    return service.name
  }

  static func normalize(_ raw: String) -> String {
    raw
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(
        of: "[^a-z0-9]+",
        with: " ",
        options: .regularExpression
      )
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
