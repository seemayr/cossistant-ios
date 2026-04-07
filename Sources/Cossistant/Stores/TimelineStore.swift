import Foundation
import Observation

/// Observable store for timeline items (messages) within a conversation.
@MainActor
@Observable
public final class TimelineStore {
  /// Timeline items for the currently active conversation, oldest first.
  public private(set) var items: [TimelineItem] = [] {
    didSet { rebuildDerivedState() }
  }

  /// Widget-visible tool names — only these tools are shown to visitors.
  /// Matches web widget's `TOOL_WIDGET_ACTIVITY_REGISTRY`.
  private static let widgetVisibleTools: Set<String> = ["searchKnowledgeBase"]

  /// Items filtered for visitor display (cached).
  /// Matches the web widget's `isBlockedTimelineEventForVisitor` + tool registry.
  public private(set) var visibleItems: [TimelineItem] = []

  /// Grouped items for display — consecutive messages from the same sender
  /// within 5 minutes are bundled, as are consecutive tool calls.
  public private(set) var itemGroups: [ItemGroup] = []

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
    let _: MarkSeenResponse = try await rest.request(.markSeen(conversationId: conversationId))
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
    guard payload.conversationId == activeConversationId else { return }
    guard let index = items.firstIndex(where: { $0.id == payload.item.id }) else { return }
    items[index] = payload.item
  }

  // MARK: - Derived State

  /// Five-minute threshold for grouping consecutive messages from the same sender.
  private static let groupingInterval: TimeInterval = 300

  /// Rebuilds cached `visibleItems` and `itemGroups` from raw `items`.
  /// Called automatically via `items.didSet`.
  private func rebuildDerivedState() {
    visibleItems = items.filter { item in
      guard item.visibility == .public else { return false }
      if item.type == .identification { return false }
      if item.type == .tool {
        let toolName = item.tool ?? item.parts.compactMap { part -> String? in
          if case .tool(let t) = part { return t.toolName }
          return nil
        }.first
        return toolName.map { Self.widgetVisibleTools.contains($0) } ?? false
      }
      return true
    }

    // Single forward pass to build groups.
    var groups: [ItemGroup] = []
    var currentItems: [TimelineItem] = []

    for item in visibleItems {
      if let previous = currentItems.last, Self.shouldGroup(item, withPrevious: previous) {
        currentItems.append(item)
      } else {
        if !currentItems.isEmpty {
          groups.append(ItemGroup(items: currentItems))
        }
        currentItems = [item]
      }
    }
    if !currentItems.isEmpty {
      groups.append(ItemGroup(items: currentItems))
    }

    itemGroups = groups
  }

  /// Determines whether `current` should join the same group as `previous`.
  private static func shouldGroup(_ current: TimelineItem, withPrevious previous: TimelineItem) -> Bool {
    // Consecutive tools cluster together.
    if current.type == .tool && previous.type == .tool {
      return true
    }

    // Only group messages with messages.
    guard current.type == .message && previous.type == .message else {
      return false
    }

    // Same sender?
    guard sameSender(current, previous) else { return false }

    // Within time threshold?
    guard let currentDate = SupportFormatters.parseISO8601(current.createdAt),
          let previousDate = SupportFormatters.parseISO8601(previous.createdAt) else {
      return false
    }
    return currentDate.timeIntervalSince(previousDate) < groupingInterval
  }

  private static func sameSender(_ a: TimelineItem, _ b: TimelineItem) -> Bool {
    if let av = a.visitorId, let bv = b.visitorId, av == bv { return true }
    if let au = a.userId, let bu = b.userId, au == bu { return true }
    if let aa = a.aiAgentId, let ba = b.aiAgentId, aa == ba { return true }
    return false
  }
}

// MARK: - Item Group

/// A group of consecutive timeline items that belong together visually.
/// Messages from the same sender within 5 minutes, or consecutive tool calls.
public struct ItemGroup: Identifiable, Sendable {
  /// Stable identity — uses the first item's ID.
  /// Falls back to createdAt to avoid generating a new UUID on every access.
  public var id: String { items[0].id ?? items[0].createdAt }

  /// The items in this group, in chronological order. Always non-empty.
  public let items: [TimelineItem]

  /// The last item's ID — useful for scroll-to-bottom targeting.
  public var lastItemId: String? { items.last?.id }
}
