import Foundation
import Observation

/// Observable store for timeline items (messages) within a conversation.
@MainActor
@Observable
public final class TimelineStore {
  /// Timeline items for the currently active conversation, oldest first.
  public private(set) var items: [TimelineItem] = []

  /// Widget-visible tool names — only these tools are shown to visitors.
  /// Matches web widget's `TOOL_WIDGET_ACTIVITY_REGISTRY`.
  private static let widgetVisibleTools: Set<String> = ["searchKnowledgeBase"]

  /// Items filtered for visitor display.
  /// Matches the web widget's `isBlockedTimelineEventForVisitor` + tool registry.
  public var visibleItems: [TimelineItem] {
    items.filter { item in
      guard item.visibility == .public else { return false }
      if item.type == .identification { return false }
      if item.type == .tool {
        // Only show widget-registered tools
        let toolName = item.tool ?? item.parts.compactMap { part -> String? in
          if case .tool(let t) = part { return t.toolName }
          return nil
        }.first
        return toolName.map { Self.widgetVisibleTools.contains($0) } ?? false
      }
      return true
    }
  }

  /// Pending messages awaiting server confirmation.
  public private(set) var pendingMessages: [PendingMessage] = []

  /// Whether older messages can be loaded.
  public private(set) var hasMore = false

  /// Whether a fetch is in progress.
  public private(set) var isLoading = false

  /// The active conversation ID, if any.
  public private(set) var activeConversationId: String?

  private var nextCursor: String?
  private let pageSize = 50
  let rest: RESTClient
  var onMessageSent: ((_ text: String) -> Void)?
  var onItemCreated: ((_ item: TimelineItem) -> Void)?

  init(rest: RESTClient) {
    self.rest = rest
  }

  // MARK: - Public API

  /// Loads the most recent messages for a conversation.
  public func load(conversationId: String) async throws {
    activeConversationId = conversationId
    nextCursor = nil
    pendingMessages = []
    isLoading = true
    defer { isLoading = false }

    let response: TimelineResponse = try await rest.request(
      .getTimeline(conversationId: conversationId, limit: pageSize, cursor: nil)
    )
    items = response.items
    nextCursor = response.nextCursor
    hasMore = response.hasNextPage
  }

  /// Loads older messages (cursor pagination).
  public func loadMore() async throws {
    guard let conversationId = activeConversationId,
          hasMore, !isLoading else { return }

    isLoading = true
    defer { isLoading = false }

    let response: TimelineResponse = try await rest.request(
      .getTimeline(conversationId: conversationId, limit: pageSize, cursor: nextCursor)
    )
    items.insert(contentsOf: response.items, at: 0)
    nextCursor = response.nextCursor
    hasMore = response.hasNextPage
  }

  /// Sends a text message with optimistic update.
  /// The message appears in `pendingMessages` immediately,
  /// then moves to `items` when the server confirms.
  public func sendMessage(text: String, visitorId: String?) async throws {
    guard let conversationId = activeConversationId else {
      SupportLogger.storeError("Timeline", action: "sendMessage", error: CossistantError.notBootstrapped)
      throw CossistantError.notBootstrapped
    }

    SupportLogger.storeAction("Timeline", action: "sendMessage to \(conversationId) (visitorId: \(visitorId ?? "nil"))")

    // Create pending message for immediate UI display
    let localId = "pending_\(UUID().uuidString)"
    let pending = PendingMessage(
      id: localId,
      conversationId: conversationId,
      text: text,
      attachments: [],
      createdAt: Date(),
      status: .sending
    )
    pendingMessages.append(pending)

    do {
      let request = SendMessageRequest(
        conversationId: conversationId,
        text: text,
        visitorId: visitorId
      )
      let response: SendMessageResponse = try await rest.request(
        .sendMessage, body: request
      )

      SupportLogger.storeAction("Timeline", action: "sendMessage OK — item id: \(response.item.id ?? "nil")")

      // Remove pending, add confirmed item
      pendingMessages.removeAll { $0.id == localId }
      if !items.contains(where: { $0.id == response.item.id }) {
        items.append(response.item)
      }
      onMessageSent?(text)
    } catch {
      SupportLogger.storeError("Timeline", action: "sendMessage", error: error)
      // Mark as failed so UI can show retry option
      if let index = pendingMessages.firstIndex(where: { $0.id == localId }) {
        pendingMessages[index].status = .failed(error.localizedDescription)
      }
      throw error
    }
  }

  // MARK: - Pending Message Helpers (used by CossistantClient)

  /// Adds a pending message for immediate UI display.
  public func appendPending(_ message: PendingMessage) {
    pendingMessages.append(message)
  }

  /// Removes a pending message after server confirmation.
  public func removePending(id: String) {
    pendingMessages.removeAll { $0.id == id }
  }

  /// Marks a pending message as failed so the UI can show retry.
  public func markPendingFailed(id: String, error: String) {
    if let index = pendingMessages.firstIndex(where: { $0.id == id }) {
      pendingMessages[index].status = .failed(error)
    }
  }

  /// Appends a timeline item if not already present (dedup).
  public func appendItemIfNew(_ item: TimelineItem) {
    guard !items.contains(where: { $0.id == item.id }) else { return }
    items.append(item)
  }

  /// Retries sending a failed pending message.
  public func retrySend(pendingId: String, visitorId: String?) async throws {
    guard let index = pendingMessages.firstIndex(where: { $0.id == pendingId }) else { return }
    let message = pendingMessages[index]
    pendingMessages.remove(at: index)
    try await sendMessage(text: message.text, visitorId: visitorId)
  }

  /// Discards a failed pending message.
  public func discardPending(pendingId: String) {
    pendingMessages.removeAll { $0.id == pendingId }
  }

  /// Marks the active conversation as seen.
  public func markSeen() async throws {
    guard let conversationId = activeConversationId else { return }
    let _: MarkSeenResponse = try await rest.request(.markSeen(conversationId: conversationId), body: [String: String]())
  }

  /// Sends typing indicator.
  public func setTyping(_ isTyping: Bool, preview: String? = nil) async throws {
    guard let conversationId = activeConversationId else { return }
    let request = SetTypingRequest(isTyping: isTyping, visitorPreview: preview)
    let _: SetTypingResponse = try await rest.request(
      .setTyping(conversationId: conversationId), body: request
    )
  }

  /// Submits a rating for the active conversation.
  public func submitRating(_ rating: Int, comment: String? = nil) async throws {
    guard let conversationId = activeConversationId else { return }
    let request = SubmitRatingRequest(rating: rating, comment: comment)
    let _: SubmitRatingResponse = try await rest.request(
      .submitRating(conversationId: conversationId), body: request
    )
  }

  /// Hydrates the timeline from a create-conversation response.
  /// Performs a full reset like `load()` but from pre-fetched data.
  func hydrate(conversationId: String, items newItems: [TimelineItem]) {
    activeConversationId = conversationId
    items = newItems
    pendingMessages = []
    nextCursor = nil
    hasMore = false
  }

  /// Clears the timeline (e.g. when switching conversations).
  public func clear() {
    items = []
    pendingMessages = []
    activeConversationId = nil
    nextCursor = nil
    hasMore = false
  }

  // MARK: - WebSocket Event Handling

  func handleTimelineItemCreated(_ payload: TimelineItemEventPayload) {
    logTimelineItem(payload.item, action: "created")
    onItemCreated?(payload.item)
    guard payload.conversationId == activeConversationId else { return }

    // Reconcile: if WS delivers a message we sent, remove the pending version
    if let visitorId = payload.item.visitorId,
       !visitorId.isEmpty,
       let pendingIndex = pendingMessages.firstIndex(where: {
         $0.text == payload.item.text && $0.conversationId == payload.conversationId
       }) {
      pendingMessages.remove(at: pendingIndex)
    }

    guard !items.contains(where: { $0.id == payload.item.id }) else { return }
    items.append(payload.item)
  }

  func handleTimelineItemUpdated(_ payload: TimelineItemEventPayload) {
    logTimelineItem(payload.item, action: "updated")
    guard payload.conversationId == activeConversationId else { return }
    guard let index = items.firstIndex(where: { $0.id == payload.item.id }) else { return }
    items[index] = payload.item
  }

  // MARK: - Logging

  private func logTimelineItem(_ item: TimelineItem, action: String) {
    let eventType = item.parts.compactMap { if case .event(let e) = $0 { e.eventType } else { nil } }.first
    let toolName = item.tool ?? item.parts.compactMap { if case .tool(let t) = $0 { t.toolName } else { nil } }.first
    let detail = eventType ?? toolName
    let sender = item.visitorId.map { "visitor:\($0)" }
      ?? item.aiAgentId.map { "ai:\($0)" }
      ?? item.userId.map { "user:\($0)" }
      ?? "unknown"
    SupportLogger.timelineItemEvent(
      action: action, type: item.type, eventType: detail,
      visibility: item.visibility, sender: sender
    )
  }
}
