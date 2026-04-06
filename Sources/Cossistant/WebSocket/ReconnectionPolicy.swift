import Foundation

/// Exponential backoff strategy for WebSocket reconnection.
struct ReconnectionPolicy: Sendable {
  private let baseDelay: TimeInterval
  private let maxDelay: TimeInterval
  private let maxAttempts: Int
  private(set) var attempt: Int = 0

  init(
    baseDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 30.0,
    maxAttempts: Int = 20
  ) {
    self.baseDelay = baseDelay
    self.maxDelay = maxDelay
    self.maxAttempts = maxAttempts
  }

  var shouldRetry: Bool {
    attempt < maxAttempts
  }

  var currentDelay: TimeInterval {
    min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
  }

  mutating func recordAttempt() {
    attempt += 1
  }

  mutating func reset() {
    attempt = 0
  }
}
