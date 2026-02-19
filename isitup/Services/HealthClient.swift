//
//  HealthClient.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation

struct HTTPCheckResult {
  let statusCode: Int
  let responseTimeMs: Int
}

protocol HealthChecking {
  func check(url: URL) async throws -> HTTPCheckResult
}

final class URLSessionHealthClient: HealthChecking {
  func check(url: URL) async throws -> HTTPCheckResult {
    var req = URLRequest(url: url)
    req.httpMethod = "HEAD"
    req.timeoutInterval = 5

    do {
      let headStart = DispatchTime.now().uptimeNanoseconds
      let (_, resp) = try await URLSession.shared.data(for: req)
      guard let http = resp as? HTTPURLResponse else { throw HealthCheckError.invalidResponse }
      let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - headStart) / 1_000_000)
      return HTTPCheckResult(statusCode: http.statusCode, responseTimeMs: elapsedMs)
    } catch {
      // If HEAD is rejected or unsupported, fall back to GET.
      var getReq = URLRequest(url: url)
      getReq.httpMethod = "GET"
      getReq.timeoutInterval = 5

      let getStart = DispatchTime.now().uptimeNanoseconds
      let (_, resp) = try await URLSession.shared.data(for: getReq)
      guard let http = resp as? HTTPURLResponse else { throw HealthCheckError.invalidResponse }
      let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - getStart) / 1_000_000)
      return HTTPCheckResult(statusCode: http.statusCode, responseTimeMs: elapsedMs)
    }
  }
}

final class MockHealthClient: HealthChecking {
  func check(url: URL) async throws -> HTTPCheckResult {
    let latencyNs = UInt64.random(in: 350_000_000...1_200_000_000)
    try await Task.sleep(nanoseconds: latencyNs)
    let latencyMs = Int(latencyNs / 1_000_000)
    let roll = Int.random(in: 1...100)
    if roll <= 70 { return HTTPCheckResult(statusCode: 200, responseTimeMs: latencyMs) }
    if roll <= 85 { return HTTPCheckResult(statusCode: 502, responseTimeMs: latencyMs) }
    throw HealthCheckError.invalidResponse
  }
}
