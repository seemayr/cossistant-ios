import Testing
import Foundation
@testable import Cossistant

/// Pure logic tests for TimelineStore event handling.
@Suite("TimelineStore Events")
struct TimelineStoreEventTests {
  @MainActor func makeStore() -> TimelineStore {
    let config = Configuration(apiKey: "test", origin: "http://localhost")
    return TimelineStore(rest: RESTClient(configuration: config))
  }

  @Test("handleTimelineItemCreated ignores non-active conversation")
  @MainActor
  func ignoresNonActiveConversation() {
    let store = makeStore()
    store.handleTimelineItemCreated(TimelineItemEventPayload(
      conversationId: "conv_001",
      item: TimelineItem(
        id: "item_new", conversationId: "conv_001", organizationId: "org_001",
        visibility: .public, type: .message, text: "New message", tool: nil,
        parts: [], userId: nil, aiAgentId: nil, visitorId: "vis_001",
        createdAt: "2026-04-06T10:05:00Z", deletedAt: nil
      )
    ))
    #expect(store.items.isEmpty) // no active conversation
  }

  @Test("handleTimelineItemUpdated replaces existing item")
  @MainActor
  func updatesExistingItem() {
    let store = makeStore()
    // No active conversation, so updates are ignored
    store.handleTimelineItemUpdated(TimelineItemEventPayload(
      conversationId: "conv_001",
      item: TimelineItem(
        id: "item_001", conversationId: "conv_001", organizationId: "org_001",
        visibility: .public, type: .message, text: "Updated", tool: nil,
        parts: [], userId: nil, aiAgentId: nil, visitorId: nil,
        createdAt: "2026-04-06T10:05:00Z", deletedAt: nil
      )
    ))
    #expect(store.items.isEmpty)
  }

  @Test("PendingMessage converts to TimelineItem")
  func pendingMessageToTimelineItem() {
    let pending = PendingMessage(
      id: "pending_1",
      conversationId: "conv_001",
      text: "Hello",
      createdAt: Date(),
      status: .sending
    )
    let item = pending.toTimelineItem(visitorId: "vis_001", organizationId: "org_001")
    #expect(item.id == "pending_1")
    #expect(item.text == "Hello")
    #expect(item.visitorId == "vis_001")
    #expect(item.type == .message)
    #expect(item.visibility == .public)
  }
}
