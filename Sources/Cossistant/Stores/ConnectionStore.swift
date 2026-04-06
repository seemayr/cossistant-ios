import Foundation
import Observation

/// Observable store for WebSocket connection state and realtime indicators.
@MainActor
@Observable
public final class ConnectionStore {
  /// Whether the WebSocket is currently connected.
  public private(set) var isConnected = false

  /// Typing indicators keyed by conversation ID.
  /// Value contains the actor info (userId or aiAgentId) and preview text.
  public private(set) var typingIndicators: [String: TypingIndicator] = [:]

  /// AI processing state keyed by conversation ID.
  public private(set) var aiProcessing: [String: AIProcessingState] = [:]

  // MARK: - Connection State

  func setConnected(_ connected: Bool) {
    isConnected = connected
  }

  // MARK: - Typing

  func handleTyping(_ payload: ConversationTypingPayload) {
    if payload.isTyping {
      typingIndicators[payload.conversationId] = TypingIndicator(
        userId: payload.userId,
        aiAgentId: payload.aiAgentId,
        preview: payload.visitorPreview
      )
    } else {
      typingIndicators.removeValue(forKey: payload.conversationId)
    }
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
    aiProcessing.removeValue(forKey: payload.conversationId)
  }
}

// MARK: - Supporting Types

public struct TypingIndicator: Sendable {
  public let userId: String?
  public let aiAgentId: String?
  public let preview: String?
}

public struct AIProcessingState: Sendable {
  public let aiAgentId: String
  public let phase: String
  public let message: String?
}
