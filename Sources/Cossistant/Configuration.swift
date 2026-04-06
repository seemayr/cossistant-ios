import Foundation

/// Configuration for the Cossistant SDK.
public struct Configuration: Sendable {
  /// Your public API key (e.g. `pk_live_xxx` or `pk_test_xxx`).
  public let apiKey: String

  /// Origin header value. Required by the Cossistant API for public key auth.
  /// Must match a whitelisted domain in your Cossistant dashboard.
  /// Test keys (`pk_test_*`) accept `http://localhost:3000`.
  public let origin: String

  /// Base URL for REST API calls.
  public let apiBaseURL: URL

  /// Base URL for WebSocket connections.
  public let webSocketBaseURL: URL

  public init(
    apiKey: String,
    origin: String,
    apiBaseURL: URL = URL(string: "https://api.cossistant.com/v1")!,
    webSocketBaseURL: URL = URL(string: "wss://api.cossistant.com/ws")!
  ) {
    self.apiKey = apiKey
    self.origin = origin
    self.apiBaseURL = apiBaseURL
    self.webSocketBaseURL = webSocketBaseURL
  }
}
