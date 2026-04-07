import Foundation
import Observation

/// Observable store for WebSocket connection state and realtime indicators.
@MainActor
@Observable
public final class ConnectionStore {
  /// Whether the WebSocket is currently connected.
  public private(set) var isConnected = false

  /// Typing indicators keyed by conversation ID.
  public private(set) var typingIndicators: [String: TypingIndicator] = [:]

  /// AI processing state keyed by conversation ID.
  public private(set) var aiProcessing: [String: AIProcessingState] = [:]

  /// Read receipts keyed by conversation ID.
  public private(set) var seenReceipts: [String: [SeenReceipt]] = [:]

  private let agents: AgentRegistry

  init(agents: AgentRegistry) {
    self.agents = agents
  }

  // MARK: - Convenience for UI

  /// Whether an agent (human or AI) is typing in a specific conversation.
  public func isAgentTyping(in conversationId: String) -> Bool {
    typingIndicators[conversationId] != nil
  }

  /// The typing preview text for a conversation, if any.
  public func typingPreview(for conversationId: String) -> String? {
    typingIndicators[conversationId]?.preview
  }

  /// The name of whoever is typing in a conversation.
  public func typingAgentName(for conversationId: String) -> String? {
    typingIndicators[conversationId]?.name
  }

  /// Whether AI is processing in a specific conversation.
  public func isAIProcessing(in conversationId: String) -> Bool {
    aiProcessing[conversationId] != nil
  }

  /// The AI processing status message for a conversation, if any.
  public func aiStatusMessage(for conversationId: String) -> String? {
    aiProcessing[conversationId]?.message
  }

  /// Read receipts for a conversation (who has seen it).
  public func seen(for conversationId: String) -> [SeenReceipt] {
    seenReceipts[conversationId] ?? []
  }

  // MARK: - Connection State

  func setConnected(_ connected: Bool) {
    isConnected = connected
  }

  // MARK: - Typing

  func handleTyping(_ payload: ConversationTypingPayload) {
    if payload.isTyping {
      // Resolve agent identity
      let agentInfo = agents.agent(forUserId: payload.userId)
        ?? agents.agent(forAIAgentId: payload.aiAgentId)

      typingIndicators[payload.conversationId] = TypingIndicator(
        userId: payload.userId,
        aiAgentId: payload.aiAgentId,
        name: agentInfo?.name,
        image: agentInfo?.image,
        preview: payload.visitorPreview
      )
    } else {
      typingIndicators.removeValue(forKey: payload.conversationId)
    }
  }

  // MARK: - Seen

  func handleSeen(_ payload: ConversationSeenPayload) {
    let agentInfo = agents.agent(forUserId: payload.actorId)
      ?? agents.agent(forAIAgentId: payload.actorId)

    let receipt = SeenReceipt(
      actorType: payload.actorType,
      actorId: payload.actorId,
      name: agentInfo?.name,
      image: agentInfo?.image,
      lastSeenAt: payload.lastSeenAt
    )

    var receipts = seenReceipts[payload.conversationId] ?? []
    // Replace existing receipt from same actor
    receipts.removeAll { $0.actorId == payload.actorId }
    receipts.append(receipt)
    seenReceipts[payload.conversationId] = receipts
  }

  // MARK: - AI Processing

  func handleAIProgress(_ payload: AIProcessingProgressPayload) {
    guard payload.audience == "all" || payload.audience == nil else { return }
    aiProcessing[payload.conversationId] = AIProcessingState(
      aiAgentId: payload.aiAgentId,
      phase: payload.phase,
      message: payload.message
    )
  }

  func handleAICompleted(_ payload: AIProcessingCompletedPayload) {
    guard payload.audience == "all" || payload.audience == nil else { return }
    aiProcessing.removeValue(forKey: payload.conversationId)
  }
}

// MARK: - Supporting Types

public struct TypingIndicator: Sendable {
  public let userId: String?
  public let aiAgentId: String?
  public let name: String?
  public let image: String?
  public let preview: String?
}

public struct AIProcessingState: Sendable {
  public let aiAgentId: String
  public let phase: String
  public let message: String?
}

public struct SeenReceipt: Sendable, Identifiable {
  public var id: String { actorId }
  public let actorType: String
  public let actorId: String
  public let name: String?
  public let image: String?
  public let lastSeenAt: String
}
