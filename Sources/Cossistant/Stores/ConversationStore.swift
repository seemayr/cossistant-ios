import Foundation
import Observation
import SwiftUI

/// Observable store for conversation state.
@MainActor
@Observable
public final class ConversationStore {
  /// All conversations, raw order from API.
  public private(set) var conversations: [Conversation] = []

  /// Conversations sorted: open first, then resolved, both by most recent.
  /// Filters out archived/deleted and empty ghost conversations.
  /// Matches web widget's `shouldDisplayConversation` filter.
  public var sorted: [Conversation] {
    let displayable = conversations.filter(shouldDisplay)
    let open = displayable.filter { $0.status == .open }.sorted { $0.updatedAt > $1.updatedAt }
    let resolved = displayable.filter { $0.status == .resolved }.sorted { $0.updatedAt > $1.updatedAt }
    return open + resolved
  }

  /// Whether any conversation passes the display filter.
  public var hasDisplayableConversations: Bool {
    conversations.contains(where: shouldDisplay)
  }

  /// Matches web widget: hide deleted + hide conversations with no title and no last message.
  func shouldDisplay(_ conversation: Conversation) -> Bool {
    if conversation.deletedAt != nil { return false }
    let hasTitle = !(conversation.title?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    let hasLastMessage = !(conversation.lastTimelineItem?.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    return hasTitle || hasLastMessage
  }

  /// Current pagination state.
  public private(set) var hasMore = false
  public private(set) var isLoading = false

  private var currentPage = 1
  private let pageSize = 20
  private let maxAutoFetchPages = 10
  private let rest: RESTClient

  init(rest: RESTClient) {
    self.rest = rest
  }

  // MARK: - Public API

  /// Fetches the first page of conversations.
  public func load() async throws {
    guard !isLoading else { return }
    currentPage = 1
    isLoading = true
    defer { isLoading = false }

    let response: ListConversationsResponse = try await rest.request(
      .listConversations(page: currentPage, limit: pageSize)
    )
    let displayableCountBefore = conversations.filter(shouldDisplay).count
    conversations = response.conversations
    hasMore = response.pagination.hasMore

    try await autoFetchIfNeeded(displayableCountBefore: displayableCountBefore)
  }

  /// Loads the next page and appends to the list.
  public func loadMore() async throws {
    guard hasMore, !isLoading else { return }

    isLoading = true
    defer { isLoading = false }

    let displayableCountBefore = conversations.filter(shouldDisplay).count
    _ = try await fetchNextPage()
    try await autoFetchIfNeeded(displayableCountBefore: displayableCountBefore)
  }

  // MARK: - Pagination Helpers

  /// Fetches a single next page and appends results.
  @discardableResult
  private func fetchNextPage() async throws -> ListConversationsResponse {
    currentPage += 1
    let response: ListConversationsResponse = try await rest.request(
      .listConversations(page: currentPage, limit: pageSize)
    )
    withCossistantAnimation(CossistantAnimation.smooth) {
      conversations.append(contentsOf: response.conversations)
      hasMore = response.pagination.hasMore
    }
    return response
  }

  /// Keeps fetching pages while `hasMore` is true but no new displayable
  /// conversations have appeared. Stops when new content is found,
  /// `hasMore` becomes false, or the safety limit is reached.
  private func autoFetchIfNeeded(displayableCountBefore: Int) async throws {
    var extraPages = 0
    while hasMore, extraPages < maxAutoFetchPages {
      let currentCount = conversations.filter(shouldDisplay).count
      if currentCount > displayableCountBefore { break }
      _ = try await fetchNextPage()
      extraPages += 1
    }
  }

  /// Creates a new conversation.
  public func create(
    _ request: CreateConversationRequest
  ) async throws -> CreateConversationResponse {
    let response: CreateConversationResponse = try await rest.request(
      .createConversation, body: request
    )
    withCossistantAnimation(CossistantAnimation.smooth) {
      conversations.insert(response.conversation, at: 0)
    }
    return response
  }

  // MARK: - Convenience for UI

  /// Total number of conversations.
  public var totalCount: Int { conversations.count }

  /// Open conversations only.
  public var openConversations: [Conversation] {
    conversations.filter { $0.status == .open }
  }

  /// Resolved conversations only.
  public var resolvedConversations: [Conversation] {
    conversations.filter { $0.status == .resolved }
  }

  /// Returns a conversation by ID, if loaded.
  public func conversation(byId id: String) -> Conversation? {
    conversations.first { $0.id == id }
  }

  // MARK: - WebSocket Event Handling

  func handleConversationCreated(_ payload: ConversationCreatedPayload) {
    guard !conversations.contains(where: { $0.id == payload.conversation.id }) else { return }
    withCossistantAnimation(CossistantAnimation.smooth) {
      conversations.insert(payload.conversation, at: 0)
    }
  }

  func handleConversationUpdated(_ payload: ConversationUpdatedPayload) {
    guard let index = conversations.firstIndex(where: { $0.id == payload.conversationId }) else { return }
    withCossistantAnimation(CossistantAnimation.smooth) {
      if let title = payload.updates.title {
        conversations[index].title = title
      }
      if let status = payload.updates.status {
        conversations[index].status = status
      }
      if let deletedAt = payload.updates.deletedAt {
        conversations[index].deletedAt = deletedAt
      }
    }
  }
}
