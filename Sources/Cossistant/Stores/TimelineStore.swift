import Foundation
import Observation

/// Observable store for timeline items (messages) within a conversation.
@MainActor
@Observable
public final class TimelineStore {
  /// Timeline items for the currently active conversation, oldest first.
  public private(set) var items: [TimelineItem] = []

  /// Whether older messages can be loaded.
  public private(set) var hasMore = false

  /// Whether a fetch is in progress.
  public private(set) var isLoading = false

  /// The active conversation ID, if any.
  public private(set) var activeConversationId: String?

  private var nextCursor: String?
  private let pageSize = 50
  private let rest: RESTClient

  init(rest: RESTClient) {
    self.rest = rest
  }

  // MARK: - Public API

  /// Loads the most recent messages for a conversation.
  public func load(conversationId: String) async throws {
    activeConversationId = conversationId
    nextCursor = nil
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

  /// Sends a text message to the active conversation.
  public func sendMessage(text: String, visitorId: String?) async throws {
    guard let conversationId = activeConversationId else {
      throw CossistantError.notBootstrapped
    }

    let request = SendMessageRequest(
      conversationId: conversationId,
      text: text,
      visitorId: visitorId
    )

    let response: SendMessageResponse = try await rest.request(
      .sendMessage, body: request
    )

    // Append if not already present (WS may have delivered it first)
    if !items.contains(where: { $0.id == response.item.id }) {
      items.append(response.item)
    }
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
    activeConversationId = nil
    nextCursor = nil
    hasMore = false
  }

  // MARK: - WebSocket Event Handling

  func handleTimelineItemCreated(_ payload: TimelineItemEventPayload) {
    guard payload.conversationId == activeConversationId else { return }
    guard !items.contains(where: { $0.id == payload.item.id }) else { return }
    items.append(payload.item)
  }

  func handleTimelineItemUpdated(_ payload: TimelineItemEventPayload) {
    guard payload.conversationId == activeConversationId else { return }
    guard let index = items.firstIndex(where: { $0.id == payload.item.id }) else { return }
    items[index] = payload.item
  }
}
