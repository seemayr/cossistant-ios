import Testing
import Foundation
@testable import Cossistant

@Suite("ConnectionStore")
struct ConnectionStoreTests {
  @MainActor func makeStore() -> ConnectionStore {
    ConnectionStore(agents: AgentRegistry())
  }

  @Test("Typing indicator set and cleared")
  @MainActor
  func typingIndicator() {
    let store = makeStore()

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

  @Test("Typing indicator resolves agent name when available")
  @MainActor
  func typingResolvesAgent() {
    let agents = AgentRegistry()
    // Populate with a test agent via the website response
    let website = try! JSONDecoder().decode(PublicWebsiteResponse.self, from: TestFixtures.websiteResponse)
    agents.populate(from: website)

    let store = ConnectionStore(agents: agents)
    store.handleTyping(ConversationTypingPayload(
      conversationId: "conv_001", isTyping: true, visitorPreview: nil,
      userId: "01KN8XRQMTFXECQVN4NDNJWCGY", aiAgentId: nil
    ))
    #expect(store.typingIndicators["conv_001"]?.name == "Askus Support")
  }

  @Test("AI processing state set and cleared")
  @MainActor
  func aiProcessingState() {
    let store = makeStore()

    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      phase: "thinking", message: "Working on it...", audience: "all"
    ))
    #expect(store.aiProcessing["conv_001"]?.phase == "thinking")

    store.handleAICompleted(AIProcessingCompletedPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      status: "success", reason: nil, audience: "all"
    ))
    // On success, shows "done" state briefly before auto-clearing
    #expect(store.aiProcessing["conv_001"]?.phase == "done")

    // Non-success clears immediately
    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_002", aiAgentId: "ai_001",
      phase: "thinking", message: nil, audience: "all"
    ))
    store.handleAICompleted(AIProcessingCompletedPayload(
      conversationId: "conv_002", aiAgentId: "ai_001",
      status: "error", reason: "failed", audience: "all"
    ))
    #expect(store.aiProcessing["conv_002"] == nil)
  }

  @Test("Dashboard-only AI events are filtered out")
  @MainActor
  func dashboardOnlyFiltered() {
    let store = makeStore()
    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      phase: "internal-analysis", message: "Team-only", audience: "dashboard"
    ))
    #expect(store.aiProcessing["conv_001"] == nil)
  }

  @Test("Connection state")
  @MainActor
  func connectionState() {
    let store = makeStore()
    #expect(store.isConnected == false)
    store.setConnected(true)
    #expect(store.isConnected == true)
    store.setConnected(false)
    #expect(store.isConnected == false)
  }

  @Test("isAgentTyping returns correct value")
  @MainActor
  func isAgentTyping() {
    let store = makeStore()
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
    let store = makeStore()
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
    let store = makeStore()
    #expect(store.isAIProcessing(in: "conv_001") == false)

    store.handleAIProgress(AIProcessingProgressPayload(
      conversationId: "conv_001", aiAgentId: "ai_001",
      phase: "searching", message: "Searching knowledge base...", audience: "all"
    ))
    #expect(store.isAIProcessing(in: "conv_001") == true)
    #expect(store.aiStatusMessage(for: "conv_001") == "Searching knowledge base...")
  }

  // MARK: - Seen Receipts

  @Test("handleSeen stores and deduplicates receipts")
  @MainActor
  func seenReceipts() {
    let store = makeStore()

    store.handleSeen(ConversationSeenPayload(
      conversationId: "conv_001", actorType: "user",
      actorId: "user_001", lastSeenAt: "2026-04-06T10:00:00Z"
    ))
    #expect(store.seen(for: "conv_001").count == 1)

    // Same actor updates, doesn't duplicate
    store.handleSeen(ConversationSeenPayload(
      conversationId: "conv_001", actorType: "user",
      actorId: "user_001", lastSeenAt: "2026-04-06T10:05:00Z"
    ))
    #expect(store.seen(for: "conv_001").count == 1)
    #expect(store.seen(for: "conv_001")[0].lastSeenAt == "2026-04-06T10:05:00Z")

    // Different actor adds
    store.handleSeen(ConversationSeenPayload(
      conversationId: "conv_001", actorType: "ai_agent",
      actorId: "ai_001", lastSeenAt: "2026-04-06T10:06:00Z"
    ))
    #expect(store.seen(for: "conv_001").count == 2)
  }
}
