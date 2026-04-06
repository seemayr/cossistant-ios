import Foundation

/// Typed events received over the Cossistant WebSocket connection.
public enum WebSocketEvent: Sendable {
  // Connection
  case connectionEstablished(connectionId: String)

  // Conversations
  case conversationCreated(ConversationCreatedPayload)
  case conversationUpdated(ConversationUpdatedPayload)
  case conversationSeen(ConversationSeenPayload)
  case conversationTyping(ConversationTypingPayload)

  // Timeline items
  case timelineItemCreated(TimelineItemEventPayload)
  case timelineItemUpdated(TimelineItemEventPayload)

  // AI agent processing
  case aiAgentProcessingProgress(AIProcessingProgressPayload)
  case aiAgentProcessingCompleted(AIProcessingCompletedPayload)

  // Visitor
  case visitorIdentified(visitorId: String)

  // Unknown event type
  case unknown(type: String)
}

// MARK: - Event Payloads

public struct ConversationCreatedPayload: Codable, Sendable {
  public let conversationId: String
  public let conversation: Conversation
}

public struct ConversationUpdatedPayload: Codable, Sendable {
  public let conversationId: String
  public let updates: ConversationUpdates
}

public struct ConversationUpdates: Codable, Sendable {
  public let title: String?
  public let status: ConversationStatus?
  public let sentiment: String?
  public let deletedAt: String?
}

public struct ConversationSeenPayload: Codable, Sendable {
  public let conversationId: String
  public let actorType: String
  public let actorId: String
  public let lastSeenAt: String
}

public struct ConversationTypingPayload: Codable, Sendable {
  public let conversationId: String
  public let isTyping: Bool
  public let visitorPreview: String?
  public let userId: String?
  public let aiAgentId: String?
}

public struct TimelineItemEventPayload: Codable, Sendable {
  public let conversationId: String
  public let item: TimelineItem
}

public struct AIProcessingProgressPayload: Codable, Sendable {
  public let conversationId: String
  public let aiAgentId: String
  public let phase: String
  public let message: String?
  public let audience: String?
}

public struct AIProcessingCompletedPayload: Codable, Sendable {
  public let conversationId: String
  public let aiAgentId: String
  public let status: String
  public let reason: String?
  public let audience: String?
}

// MARK: - Event Parsing

enum WebSocketEventParser {
  /// Parses a WebSocket message.
  /// The server sends events as `{ "type": "eventName", "payload": { ... } }`.
  /// We extract the payload and decode each event type from it.
  static func parse(from data: Data) -> WebSocketEvent? {
    guard let envelope = try? JSONDecoder().decode(EventEnvelope.self, from: data) else {
      return nil
    }

    // The actual event data is nested under "payload".
    // If no payload key exists, fall back to the root (for test fixtures / backwards compat).
    let payloadData: Data
    if let payload = envelope.payload {
      guard let encoded = try? JSONSerialization.data(withJSONObject: payload) else {
        return .unknown(type: envelope.type)
      }
      payloadData = encoded
    } else {
      payloadData = data
    }

    let decoder = JSONDecoder()

    switch envelope.type {
    case "CONNECTION_ESTABLISHED":
      return .connectionEstablished(connectionId: "")

    case "conversationCreated":
      guard let payload = try? decoder.decode(ConversationCreatedPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .conversationCreated(payload)

    case "conversationUpdated":
      guard let payload = try? decoder.decode(ConversationUpdatedPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .conversationUpdated(payload)

    case "conversationSeen":
      guard let payload = try? decoder.decode(ConversationSeenPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .conversationSeen(payload)

    case "conversationTyping":
      guard let payload = try? decoder.decode(ConversationTypingPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .conversationTyping(payload)

    case "timelineItemCreated":
      guard let payload = try? decoder.decode(TimelineItemEventPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .timelineItemCreated(payload)

    case "timelineItemUpdated":
      guard let payload = try? decoder.decode(TimelineItemEventPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .timelineItemUpdated(payload)

    case "aiAgentProcessingProgress":
      guard let payload = try? decoder.decode(AIProcessingProgressPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .aiAgentProcessingProgress(payload)

    case "aiAgentProcessingCompleted":
      guard let payload = try? decoder.decode(AIProcessingCompletedPayload.self, from: payloadData) else { return .unknown(type: envelope.type) }
      return .aiAgentProcessingCompleted(payload)

    case "visitorIdentified":
      let visitorId = envelope.visitorId ?? ""
      return .visitorIdentified(visitorId: visitorId)

    default:
      return .unknown(type: envelope.type)
    }
  }
}

/// Envelope that extracts the type and optional nested payload.
/// Server format: `{ "type": "eventName", "payload": { ... } }`
private struct EventEnvelope: Codable {
  let type: String
  let visitorId: String?
  let payload: [String: Any]?

  enum CodingKeys: String, CodingKey {
    case type, visitorId, payload
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decode(String.self, forKey: .type)
    visitorId = try container.decodeIfPresent(String.self, forKey: .visitorId)

    // Decode payload as raw dictionary
    if let payloadContainer = try? container.decode(AnyCodable.self, forKey: .payload) {
      payload = payloadContainer.value as? [String: Any]
    } else {
      payload = nil
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(visitorId, forKey: .visitorId)
  }
}

/// Helper to decode arbitrary JSON values.
private struct AnyCodable: Codable {
  let value: Any

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let dict = try? container.decode([String: AnyCodable].self) {
      value = dict.mapValues { $0.value }
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map { $0.value }
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if container.decodeNil() {
      value = NSNull()
    } else {
      value = NSNull()
    }
  }

  func encode(to encoder: Encoder) throws {
    // Not needed for our use case
  }
}
