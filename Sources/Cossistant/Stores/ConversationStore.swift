import Foundation
import Observation

/// Observable store for conversation state.
@MainActor
@Observable
public final class ConversationStore {
  /// All conversations, most recently updated first.
  public private(set) var conversations: [Conversation] = []

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
