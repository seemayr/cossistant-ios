import Testing
@testable import Cossistant

@Suite("ReconnectionPolicy")
struct ReconnectionPolicyTests {
  @Test("Initial state")
  func initialState() {
    let policy = ReconnectionPolicy()
    #expect(policy.shouldRetry == true)
    #expect(policy.attempt == 0)
    #expect(policy.currentDelay == 1.0)
  }

  @Test("Exponential backoff")
  func exponentialBackoff() {
    var policy = ReconnectionPolicy(baseDelay: 1.0, maxDelay: 30.0, maxAttempts: 20)

    // attempt 0: 1s
    #expect(policy.currentDelay == 1.0)
    policy.recordAttempt()

    // attempt 1: 2s
    #expect(policy.currentDelay == 2.0)
    policy.recordAttempt()

    // attempt 2: 4s
    #expect(policy.currentDelay == 4.0)
    policy.recordAttempt()

    // attempt 3: 8s
    #expect(policy.currentDelay == 8.0)
    policy.recordAttempt()

    // attempt 4: 16s
    #expect(policy.currentDelay == 16.0)
    policy.recordAttempt()

    // attempt 5: 30s (capped at maxDelay)
    #expect(policy.currentDelay == 30.0)
  }

  @Test("Max attempts stops retry")
  func maxAttempts() {
    var policy = ReconnectionPolicy(baseDelay: 1.0, maxDelay: 30.0, maxAttempts: 3)
    #expect(policy.shouldRetry == true)

    policy.recordAttempt()
    policy.recordAttempt()
    policy.recordAttempt()
    #expect(policy.shouldRetry == false)
  }

  @Test("Reset clears attempts")
  func reset() {
    var policy = ReconnectionPolicy(maxAttempts: 3)
    policy.recordAttempt()
    policy.recordAttempt()
    #expect(policy.attempt == 2)

    policy.reset()
    #expect(policy.attempt == 0)
    #expect(policy.shouldRetry == true)
  }
}
