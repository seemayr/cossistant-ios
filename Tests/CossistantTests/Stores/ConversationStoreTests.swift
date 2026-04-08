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

  // MARK: - hasUnread

  /// Helper: inserts a conversation via WS event and gives it a title so shouldDisplay passes.
  @MainActor
  private func insertDisplayableConversation(into store: ConversationStore) {
    let event = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent)!
    if case .conversationCreated(let payload) = event {
      store.handleConversationCreated(payload)
    }
    let update = ConversationUpdatedPayload(
      conversationId: "conv_new",
      updates: ConversationUpdates(title: "Help", status: nil, sentiment: nil, deletedAt: nil)
    )
    store.handleConversationUpdated(update)
  }

  @Test("hasUnread is true when visitorLastSeenAt is nil")
  @MainActor
  func hasUnreadNilLastSeen() throws {
    let store = makeStore()
    insertDisplayableConversation(into: store)
    #expect(store.hasUnread == true)
  }

  @Test("hasUnread is false when no displayable conversations")
  @MainActor
  func hasUnreadEmpty() throws {
    let store = makeStore()
    #expect(store.hasUnread == false)
  }

  @Test("hasUnread is false for resolved conversations")
  @MainActor
  func hasUnreadResolved() throws {
    let store = makeStore()
    insertDisplayableConversation(into: store)
    let update = ConversationUpdatedPayload(
      conversationId: "conv_new",
      updates: ConversationUpdates(title: "Help", status: .resolved, sentiment: nil, deletedAt: nil)
    )
    store.handleConversationUpdated(update)
    #expect(store.hasUnread == false)
  }

  @Test("hasUnread becomes false after markVisitorSeen")
  @MainActor
  func hasUnreadAfterMarkSeen() throws {
    let store = makeStore()
    insertDisplayableConversation(into: store)
    #expect(store.hasUnread == true)
    store.markVisitorSeen(conversationId: "conv_new")
    #expect(store.hasUnread == false)
  }

  @Test("handleConversationSeen updates visitorLastSeenAt for visitor actor")
  @MainActor
  func handleConversationSeenVisitor() throws {
    let store = makeStore()
    insertDisplayableConversation(into: store)
    #expect(store.hasUnread == true)
    let payload = ConversationSeenPayload(
      conversationId: "conv_new",
      actorType: .visitor,
      actorId: "vis_001",
      lastSeenAt: "2099-01-01T00:00:00.000Z"
    )
    store.handleConversationSeen(payload)
    #expect(store.hasUnread == false)
  }

  @Test("handleConversationSeen ignores non-visitor actors")
  @MainActor
  func handleConversationSeenAgent() throws {
    let store = makeStore()
    insertDisplayableConversation(into: store)
    #expect(store.hasUnread == true)
    let payload = ConversationSeenPayload(
      conversationId: "conv_new",
      actorType: .user,
      actorId: "agent_001",
      lastSeenAt: "2099-01-01T00:00:00.000Z"
    )
    store.handleConversationSeen(payload)
    // Should still be unread — agent seeing it doesn't clear visitor's unread
    #expect(store.hasUnread == true)
  }

  @Test("hasUnread is false when last timeline item is visitor-authored")
  @MainActor
  func hasUnreadVisitorAuthored() throws {
    let store = makeStore()
    // Decode a conversation with a visitor-authored lastTimelineItem
    let json = """
    {
      "type": "conversationCreated",
      "websiteId": "web_001",
      "organizationId": "org_001",
      "visitorId": "vis_001",
      "conversationId": "conv_visitor",
      "conversation": {
        "id": "conv_visitor",
        "title": "Help",
        "createdAt": "2026-04-06T11:00:00.000Z",
        "updatedAt": "2026-04-06T12:00:00.000Z",
        "visitorId": "vis_001",
        "websiteId": "web_001",
        "status": "open",
        "visitorLastSeenAt": "2026-04-06T11:00:00.000Z",
        "lastTimelineItem": {
          "id": "tl_visitor",
          "conversationId": "conv_visitor",
          "organizationId": "org_001",
          "visibility": "public",
          "type": "message",
          "text": "Hello",
          "parts": [],
          "userId": null,
          "aiAgentId": null,
          "visitorId": "vis_001",
          "createdAt": "2026-04-06T12:00:00.000Z",
          "deletedAt": null
        }
      }
    }
    """.data(using: .utf8)!
    let event = WebSocketEventParser.parse(from: json)!
    if case .conversationCreated(let payload) = event {
      store.handleConversationCreated(payload)
    }
    // updatedAt > visitorLastSeenAt, but last item is visitor-authored → not unread
    #expect(store.hasUnread == false)
  }
}
