//
//  SampleStore.swift
//  isitup
//
//  Created by Preyash Yadav on 2/19/26.
//

import Foundation

protocol SampleStoring: AnyObject {
  func loadSamples(for serviceID: String) -> [CheckSample]
  @discardableResult
  func appendSample(_ sample: CheckSample, for serviceID: String) -> [CheckSample]
  func clearAllSamples()
}

final class SampleStore: SampleStoring {
  static let shared = SampleStore()

  private let maxSamplesPerService = 200
  private let fileURL: URL
  private var storage: [String: [StoredSample]] = [:]
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private struct StoredSample: Codable {
    let at: Date
    let responseTimeMs: Int?
    let status: HealthState
    let isSimulated: Bool?
  }

  private init(fileManager: FileManager = .default) {
    let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    let baseDir = docsDir ?? fileManager.temporaryDirectory
    self.fileURL = baseDir.appendingPathComponent("isitup.samples.json")
    loadFromDisk()
  }

  func loadSamples(for serviceID: String) -> [CheckSample] {
    let persisted = storage[serviceID] ?? []
    return persisted.map {
      CheckSample(
        at: $0.at,
        state: $0.status,
        statusCode: nil,
        responseTimeMs: $0.responseTimeMs,
        message: nil,
        isSimulated: $0.isSimulated
      )
    }
  }

  @discardableResult
  func appendSample(_ sample: CheckSample, for serviceID: String) -> [CheckSample] {
    guard canPersist(state: sample.state) else {
      return loadSamples(for: serviceID)
    }

    let entry = StoredSample(
      at: sample.at,
      responseTimeMs: sample.responseTimeMs,
      status: sample.state,
      isSimulated: sample.isSimulated
    )

    var updated = storage[serviceID] ?? []
    updated.append(entry)

    if updated.count > maxSamplesPerService {
      updated.removeFirst(updated.count - maxSamplesPerService)
    }

    storage[serviceID] = updated
    saveToDisk()

    return loadSamples(for: serviceID)
  }

  func clearAllSamples() {
    storage = [:]
    saveToDisk()
  }

  private func canPersist(state: HealthState) -> Bool {
    switch state {
    case .healthy, .degrading, .down, .error:
      return true
    case .unknown, .checking:
      return false
    }
  }

  private func loadFromDisk() {
    guard let data = try? Data(contentsOf: fileURL),
          let decoded = try? decoder.decode([String: [StoredSample]].self, from: data) else {
      storage = [:]
      return
    }
    storage = decoded
  }

  private func saveToDisk() {
    guard let data = try? encoder.encode(storage) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
