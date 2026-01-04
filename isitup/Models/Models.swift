//
//  Models.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation

enum HealthState: String, Codable {
  case unknown
  case checking
  case healthy
  case down
  case error
}

struct HealthResponse: Codable {
  let status: String
  let timestamp: String?
}

struct ServiceDefinition: Identifiable, Hashable {
  let id: UUID
  let name: String
  let baseURL: URL?      // checking URls
  let path: String       // endpoints: "/health (for my portfolio)
}

struct ServiceStatus: Identifiable, Hashable {
  let id: UUID
  let name: String
  let endpoint: URL?
  var state: HealthState
  var lastCheckedAt: Date?
  var message: String?
    var samples: [CheckSample] = []


  var lastCheckedLabel: String {
    guard let dt = lastCheckedAt else { return "—" }
    let fmt = DateFormatter()
    fmt.dateStyle = .none
    fmt.timeStyle = .medium
    return fmt.string(from: dt)
  }
}

struct ServiceConfig: Codable, Hashable {
  var name: String
  var url: String
}

struct CheckSample: Identifiable, Hashable {
  let id = UUID()
  let at: Date
  let state: HealthState
  let statusCode: Int?
  let message: String?
}


enum ServiceStoreError: Error {
  case missingResource
  case decodeFailed
}


enum HealthCheckError: Error, LocalizedError {
  case invalidResponse
  case non200(Int)
  case decodeFailed
  case emptyURL

  var errorDescription: String? {
    switch self {
    case .invalidResponse: return "Invalid response"
    case .non200(let code): return "HTTP \(code)"
    case .decodeFailed: return "Failed to decode JSON"
    case .emptyURL: return "No endpoint configured"
    }
  }
}

