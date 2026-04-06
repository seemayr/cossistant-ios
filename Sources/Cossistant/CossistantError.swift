import Foundation

/// Unified error type for all Cossistant SDK operations.
public enum CossistantError: Error, Sendable {
  /// HTTP request failed with a status code and optional response body.
  case httpError(statusCode: Int, body: Data?)

  /// JSON decoding failed for a specific endpoint.
  case decodingError(underlying: Error, endpoint: String)

  /// WebSocket disconnected unexpectedly.
  case webSocketDisconnected(reason: String?)

  /// WebSocket heartbeat timed out (no pong received).
  case heartbeatTimeout

  /// Attempted an operation that requires an active WebSocket connection.
  case notConnected

  /// Attempted an operation before `bootstrap()` was called.
  case notBootstrapped

  /// The visitor has been blocked by the support team.
  case visitorBlocked

  /// A network or URL error from URLSession.
  case networkError(underlying: Error)
}
