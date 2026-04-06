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
  static func parse(from data: Data) -> WebSocketEvent? {
    guard let envelope = try? JSONDecoder().decode(EventEnvelope.self, from: data) else {
      return nil
    }

    let decoder = JSONDecoder()

    switch envelope.type {
    case "conversationCreated":
      guard let payload = try? decoder.decode(ConversationCreatedPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .conversationCreated(payload)

    case "conversationUpdated":
      guard let payload = try? decoder.decode(ConversationUpdatedPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .conversationUpdated(payload)

    case "conversationSeen":
      guard let payload = try? decoder.decode(ConversationSeenPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .conversationSeen(payload)

    case "conversationTyping":
      guard let payload = try? decoder.decode(ConversationTypingPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .conversationTyping(payload)

    case "timelineItemCreated":
      guard let payload = try? decoder.decode(TimelineItemEventPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .timelineItemCreated(payload)

    case "timelineItemUpdated":
      guard let payload = try? decoder.decode(TimelineItemEventPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .timelineItemUpdated(payload)

    case "aiAgentProcessingProgress":
      guard let payload = try? decoder.decode(AIProcessingProgressPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .aiAgentProcessingProgress(payload)

    case "aiAgentProcessingCompleted":
      guard let payload = try? decoder.decode(AIProcessingCompletedPayload.self, from: data) else { return .unknown(type: envelope.type) }
      return .aiAgentProcessingCompleted(payload)

    case "visitorIdentified":
      let visitorId = envelope.visitorId ?? ""
      return .visitorIdentified(visitorId: visitorId)

    default:
      return .unknown(type: envelope.type)
    }
  }
}

/// Minimal envelope to extract the event type before full parsing.
private struct EventEnvelope: Codable {
  let type: String
  let visitorId: String?
}
