import Foundation
import Observation

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

  /// Matches web widget: hide deleted + hide conversations with no title and no last message.
  private func shouldDisplay(_ conversation: Conversation) -> Bool {
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
  private let rest: RESTClient

  init(rest: RESTClient) {
    self.rest = rest
  }

  // MARK: - Public API

  /// Fetches the first page of conversations.
  public func load() async throws {
    currentPage = 1
    isLoading = true
    defer { isLoading = false }

    let response: ListConversationsResponse = try await rest.request(
      .listConversations(page: currentPage, limit: pageSize)
    )
    conversations = response.conversations
    hasMore = response.pagination.hasMore
  }

  /// Loads the next page and appends to the list.
  public func loadMore() async throws {
    guard hasMore, !isLoading else { return }

    currentPage += 1
    isLoading = true
    defer { isLoading = false }

    let response: ListConversationsResponse = try await rest.request(
      .listConversations(page: currentPage, limit: pageSize)
    )
    conversations.append(contentsOf: response.conversations)
    hasMore = response.pagination.hasMore
  }

  /// Creates a new conversation.
  public func create(
    _ request: CreateConversationRequest
  ) async throws -> CreateConversationResponse {
    let response: CreateConversationResponse = try await rest.request(
      .createConversation, body: request
    )
    conversations.insert(response.conversation, at: 0)
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
    conversations.insert(payload.conversation, at: 0)
  }

  func handleConversationUpdated(_ payload: ConversationUpdatedPayload) {
    guard let index = conversations.firstIndex(where: { $0.id == payload.conversationId }) else { return }
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
