import Foundation
import os.log

/// Centralized logger for the Cossistant SDK.
/// Logs to both os.log (Console.app, Instruments) and print() (Xcode console).
enum SupportLogger {
  private static let subsystem = "com.cossistant.sdk"
  private static let prefix = "🟣 [Cossistant]"

  private static let network = Logger(subsystem: subsystem, category: "network")
  private static let websocket = Logger(subsystem: subsystem, category: "websocket")
  private static let store = Logger(subsystem: subsystem, category: "store")
  private static let client = Logger(subsystem: subsystem, category: "client")

  /// Whether print() logging is enabled (always visible in Xcode console).
  public nonisolated(unsafe) static var printEnabled = true

  /// Whether verbose network logging (headers + body) is enabled.
  /// Off by default to avoid JSON pretty-print overhead on hot paths.
  public nonisolated(unsafe) static var verboseNetworkLogging = false

  private static func log(_ message: String) {
    if printEnabled {
      print("\(prefix) \(message)")
    }
  }

  // MARK: - Network (REST)

  static func requestStarted(_ method: String, path: String) {
    let msg = "[\(method)] \(path)"
    network.debug("\(msg)")
    log(msg)
  }

  static func requestHeaders(
    _ method: String,
    path: String,
    origin: String,
    publicKey: String,
    visitorId: String?
  ) {
    guard verboseNetworkLogging else { return }
    let maskedPublicKey: String
    if publicKey.count > 12 {
      maskedPublicKey = "\(publicKey.prefix(8))...\(publicKey.suffix(4))"
    } else {
      maskedPublicKey = publicKey
    }

    let visitorPart = visitorId ?? "(none)"
    let msg = "[\(method)] \(path) headers: Origin=\(origin) X-Public-Key=\(maskedPublicKey) X-Visitor-Id=\(visitorPart)"
    network.debug("\(msg)")
    log(msg)
  }

  static func requestDetails(
    _ method: String,
    path: String,
    headers: [String: String],
    body: Data?
  ) {
    guard verboseNetworkLogging else { return }
    let sortedHeaders = headers
      .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: " ")

    let bodyString: String
    if let body,
       let jsonObject = try? JSONSerialization.jsonObject(with: body),
       let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
       let prettyString = String(data: prettyData, encoding: .utf8) {
      bodyString = prettyString
    } else if let body,
              let rawString = String(data: body, encoding: .utf8) {
      bodyString = rawString
    } else {
      bodyString = "(empty)"
    }

    let msg = """
    [\(method)] \(path) request:
    headers: \(sortedHeaders)
    body: \(bodyString)
    """
    network.debug("\(msg)")
    log(msg)
  }

  static func requestSuccess(_ method: String, path: String, status: Int) {
    let msg = "[\(method)] \(path) → \(status) ✓"
    network.info("\(msg)")
    log(msg)
  }

  static func requestFailed(_ method: String, path: String, error: Error) {
    let msg = "[\(method)] \(path) FAILED: \(error.localizedDescription)"
    network.error("\(msg)")
    log("⚠️ \(msg)")
  }

  static func requestHTTPError(_ method: String, path: String, status: Int, body: Data?) {
    let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? "(empty)"
    let msg = "[\(method)] \(path) HTTP \(status): \(bodyString)"
    network.error("\(msg)")
    log("❌ \(msg)")
  }

  static func decodingError(_ path: String, error: Error) {
    let msg = "[DECODE] \(path): \(error)"
    network.error("\(msg)")
    log("❌ \(msg)")
  }

  // MARK: - WebSocket

  static func wsConnecting(url: String) {
    let msg = "[WS] Connecting: \(url)"
    websocket.info("\(msg)")
    log(msg)
  }

  static func wsConnected() {
    let msg = "[WS] Connected ✓"
    websocket.info("\(msg)")
    log(msg)
  }

  static func wsDisconnected(reason: String?) {
    let msg = "[WS] Disconnected: \(reason ?? "clean")"
    websocket.info("\(msg)")
    log(msg)
  }

  static func wsEventReceived(_ type: String) {
    let msg = "[WS] Event: \(type)"
    websocket.debug("\(msg)")
    log(msg)
  }

  static func wsEventParseFailed(_ rawText: String) {
    let msg = "[WS] Failed to parse: \(rawText.prefix(300))"
    websocket.warning("\(msg)")
    log("⚠️ \(msg)")
  }

  static func wsReconnecting(attempt: Int, delay: Double) {
    let msg = "[WS] Reconnecting (attempt \(attempt), delay \(String(format: "%.1f", delay))s)"
    websocket.info("\(msg)")
    log("🔄 \(msg)")
  }

  static func wsSendFailed(_ error: Error) {
    let msg = "[WS] Send failed: \(error.localizedDescription)"
    websocket.error("\(msg)")
    log("❌ \(msg)")
  }

  static func wsReceiveError(_ error: Error) {
    let msg = "[WS] Receive error: \(error.localizedDescription)"
    websocket.error("\(msg)")
    log("❌ \(msg)")
  }

  // MARK: - Stores

  static func storeAction(_ storeName: String, action: String) {
    let msg = "[\(storeName)] \(action)"
    store.debug("\(msg)")
    log(msg)
  }

  static func storeError(_ storeName: String, action: String, error: Error) {
    let msg = "[\(storeName)] \(action) FAILED: \(error.localizedDescription)"
    store.error("\(msg)")
    log("❌ \(msg)")
  }

  // MARK: - Timeline Items

  static func timelineItemEvent(action: String, type: TimelineItemType, eventType: String?,
                                 visibility: TimelineItemVisibility, sender: String) {
    let typePart = eventType.map { "\(type.rawValue):\($0)" } ?? type.rawValue
    let msg = "[Timeline] \(action) \(typePart)(\(visibility.rawValue)) sender=\(sender)"
    store.debug("\(msg)")
    log(msg)
  }

  // MARK: - Client

  static func bootstrapStarted() {
    let msg = "[Client] Bootstrap started"
    client.info("\(msg)")
    log(msg)
  }

  static func bootstrapSuccess(visitorId: String, websiteId: String) {
    let msg = "[Client] Bootstrap OK — visitor: \(visitorId), website: \(websiteId)"
    client.info("\(msg)")
    log("✅ \(msg)")
  }

  static func bootstrapFailed(_ error: Error) {
    let msg = "[Client] Bootstrap FAILED: \(error.localizedDescription)"
    client.error("\(msg)")
    log("❌ \(msg)")
  }

  static func identifySuccess(contactId: String) {
    let msg = "[Client] Identify OK — contact: \(contactId)"
    client.info("\(msg)")
    log("✅ \(msg)")
  }

  static func identifyFailed(_ error: Error) {
    let msg = "[Client] Identify FAILED: \(error.localizedDescription)"
    client.error("\(msg)")
    log("❌ \(msg)")
  }

}
