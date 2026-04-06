import Testing
import Foundation
@testable import Cossistant

/// Pure logic tests for ConversationStore (no network mocking needed).
@Suite("ConversationStore Events")
struct ConversationStoreEventTests {
  @MainActor func makeStore() -> ConversationStore {
    let config = Configuration(apiKey: "test", origin: "http://localhost")
    return ConversationStore(rest: RESTClient(configuration: config))
  }

  @Test("handleConversationCreated inserts at front")
  @MainActor
  func handleConversationCreated() throws {
    let store = makeStore()
    let event = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent)!
    if case .conversationCreated(let payload) = event {
      store.handleConversationCreated(payload)
      #expect(store.conversations.count == 1)
      #expect(store.conversations[0].id == "conv_new")
    }
  }

  @Test("handleConversationCreated deduplicates")
  @MainActor
  func handleConversationCreatedDedup() throws {
    let store = makeStore()
    let event = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent)!
    if case .conversationCreated(let payload) = event {
      store.handleConversationCreated(payload)
      store.handleConversationCreated(payload)
      #expect(store.conversations.count == 1)
    }
  }

  @Test("handleConversationUpdated applies title and status")
  @MainActor
  func handleConversationUpdated() throws {
    let store = makeStore()
    // First insert a conversation
    let createEvent = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent)!
    if case .conversationCreated(let payload) = createEvent {
      store.handleConversationCreated(payload)
    }
    #expect(store.conversations[0].status == .open)
    #expect(store.conversations[0].title == nil)

    // Now update it — need to use conv_new's ID which matches conversationCreatedEvent
    // But conversationUpdatedEvent uses conv_001. Let me construct inline:
    let updatePayload = ConversationUpdatedPayload(
      conversationId: "conv_new",
      updates: ConversationUpdates(title: "Billing Help", status: .resolved, sentiment: nil, deletedAt: nil)
    )
    store.handleConversationUpdated(updatePayload)

    #expect(store.conversations[0].title == "Billing Help")
    #expect(store.conversations[0].status == .resolved)
  }

  @Test("Convenience: openConversations filters by status")
  @MainActor
  func openConversationsFilter() throws {
    let store = makeStore()
    let event = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent)!
    if case .conversationCreated(let payload) = event {
      store.handleConversationCreated(payload)
    }
    #expect(store.openConversations.count == 1)

    // Resolve it
    let update = ConversationUpdatedPayload(
      conversationId: "conv_new",
      updates: ConversationUpdates(title: nil, status: .resolved, sentiment: nil, deletedAt: nil)
    )
    store.handleConversationUpdated(update)
    #expect(store.openConversations.isEmpty)
    #expect(store.totalCount == 1)
  }

  @Test("conversation(byId:) finds loaded conversation")
  @MainActor
  func conversationById() throws {
    let store = makeStore()
    let event = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent)!
    if case .conversationCreated(let payload) = event {
      store.handleConversationCreated(payload)
    }
    #expect(store.conversation(byId: "conv_new") != nil)
    #expect(store.conversation(byId: "nonexistent") == nil)
  }
}
