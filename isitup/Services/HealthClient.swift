//
//  HealthClient.swift
//  isitup
//
//  Created by Preyash Yadav on 7/14/25.
//

import Foundation

struct HTTPCheckResult {
  let statusCode: Int
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
      let (_, resp) = try await URLSession.shared.data(for: req)
      guard let http = resp as? HTTPURLResponse else { throw HealthCheckError.invalidResponse }
      return HTTPCheckResult(statusCode: http.statusCode)
    } catch {
      // if not HEAD, fallback to GET
      var getReq = URLRequest(url: url)
      getReq.httpMethod = "GET"
      getReq.timeoutInterval = 5

      let (_, resp) = try await URLSession.shared.data(for: getReq)
      guard let http = resp as? HTTPURLResponse else { throw HealthCheckError.invalidResponse }
      return HTTPCheckResult(statusCode: http.statusCode)
    }
  }
}

final class MockHealthClient: HealthChecking {
  func check(url: URL) async throws -> HTTPCheckResult {
    try await Task.sleep(nanoseconds: UInt64.random(in: 350_000_000...1_200_000_000))
    let roll = Int.random(in: 1...100)
    if roll <= 70 { return HTTPCheckResult(statusCode: 200) }
    if roll <= 85 { return HTTPCheckResult(statusCode: 502) }
    throw HealthCheckError.invalidResponse
  }
}
