import Testing
import Foundation
@testable import Cossistant

@Suite("ConnectionStore")
struct ConnectionStoreTests {
  @Test("Typing indicator set and cleared")
  @MainActor
  func typingIndicator() {
    let store = ConnectionStore()

    store.handleTyping(ConversationTypingPayload(
      conversationId: "conv_001", isTyping: true, visitorPreview: "Hello...",
      userId: "user_001", aiAgentId: nil
    ))
    #expect(store.typingIndicators["conv_001"] != nil)
    #expect(store.typingIndicators["conv_001"]?.preview == "Hello...")

    store.handleTyping(ConversationTypingPayload(
      conversationId: "conv_001", isTyping: false, visitorPreview: nil,
      userId: "user_001", aiAgentId: nil
    ))
    #expect(store.typingIndicators["conv_001"] == nil)
  }

  @Test("AI processing state set and cleared")
  @MainActor
  func aiProcessingState() {
    let store = ConnectionStore()

    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      phase: "thinking", message: "Working on it...", audience: "all"
    ))
    #expect(store.aiProcessing["conv_001"]?.phase == "thinking")

    store.handleAICompleted(AIProcessingCompletedPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      status: "success", reason: nil, audience: "all"
    ))
    #expect(store.aiProcessing["conv_001"] == nil)
  }

  @Test("Dashboard-only AI events are filtered out")
  @MainActor
  func dashboardOnlyFiltered() {
    let store = ConnectionStore()
    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      phase: "internal-analysis", message: "Team-only", audience: "dashboard"
    ))
    #expect(store.aiProcessing["conv_001"] == nil)
  }

  @Test("Connection state")
  @MainActor
  func connectionState() {
    let store = ConnectionStore()
    #expect(store.isConnected == false)
    store.setConnected(true)
    #expect(store.isConnected == true)
    store.setConnected(false)
    #expect(store.isConnected == false)
  }

  // MARK: - Convenience APIs

  @Test("isAgentTyping returns correct value")
  @MainActor
  func isAgentTyping() {
    let store = ConnectionStore()
    #expect(store.isAgentTyping(in: "conv_001") == false)

    store.handleTyping(ConversationTypingPayload(
      conversationId: "conv_001", isTyping: true, visitorPreview: nil,
      userId: "user_001", aiAgentId: nil
    ))
    #expect(store.isAgentTyping(in: "conv_001") == true)
    #expect(store.isAgentTyping(in: "conv_other") == false)
  }

  @Test("typingPreview returns preview text")
  @MainActor
  func typingPreview() {
    let store = ConnectionStore()
    store.handleTyping(ConversationTypingPayload(
      conversationId: "conv_001", isTyping: true, visitorPreview: "Let me check...",
      userId: nil, aiAgentId: "ai_001"
    ))
    #expect(store.typingPreview(for: "conv_001") == "Let me check...")
    #expect(store.typingPreview(for: "conv_other") == nil)
  }

  @Test("isAIProcessing and aiStatusMessage")
  @MainActor
  func aiConvenienceAPIs() {
    let store = ConnectionStore()
    #expect(store.isAIProcessing(in: "conv_001") == false)

    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      phase: "searching", message: "Searching knowledge base...", audience: "all"
    ))
    #expect(store.isAIProcessing(in: "conv_001") == true)
    #expect(store.aiStatusMessage(for: "conv_001") == "Searching knowledge base...")
  }
}
