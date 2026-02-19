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
  case degrading
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

struct ServiceConfig: Codable, Hashable, Identifiable {
  var id: String
  var name: String
  var url: String

  init(id: String = UUID().uuidString, name: String, url: String) {
    self.id = id
    self.name = name
    self.url = url
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case url
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
    self.name = try container.decode(String.self, forKey: .name)
    self.url = try container.decode(String.self, forKey: .url)
  }
}

struct CheckSample: Identifiable, Hashable, Codable {
  var id: UUID = UUID()
  let at: Date
  let state: HealthState
  let statusCode: Int?
  let responseTimeMs: Int?
  let message: String?
  var isSimulated: Bool? = nil
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
