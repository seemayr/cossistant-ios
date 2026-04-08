import Foundation

// MARK: - Conversation

public struct Conversation: Codable, Sendable, Identifiable {
  public let id: String
  public var title: String?
  public let createdAt: String
  public let updatedAt: String
  public let visitorId: String
  public let websiteId: String
  public var status: ConversationStatus
  public var visitorRating: Int?
  public var visitorRatingAt: String?
  public var deletedAt: String?
  public var visitorLastSeenAt: String?
  public let lastTimelineItem: TimelineItem?
}

extension Conversation {
  /// Whether this conversation is closed (resolved, spam, or deleted/archived).
  /// Matches the web widget's `isConversationClosed` logic.
  public var isClosed: Bool {
    status == .resolved || status == .spam || deletedAt != nil
  }
}

public enum ConversationStatus: String, Codable, Sendable {
  case open
  case resolved
  case spam
}

// MARK: - List Conversations Response

public struct ListConversationsResponse: Codable, Sendable {
  public let conversations: [Conversation]
  public let pagination: Pagination
}

public struct Pagination: Codable, Sendable {
  public let page: Int
  public let limit: Int
  public let total: Int
  public let totalPages: Int
  public let hasMore: Bool
}

// MARK: - Create Conversation

public struct CreateConversationRequest: Codable, Sendable {
  public let visitorId: String?
  public let conversationId: String?
  public let defaultTimelineItems: [TimelineItem]
  public let channel: String

  public init(
    visitorId: String? = nil,
    conversationId: String? = nil,
    defaultTimelineItems: [TimelineItem] = [],
    channel: String = "mobile"
  ) {
    self.visitorId = visitorId
    self.conversationId = conversationId
    self.defaultTimelineItems = defaultTimelineItems
    self.channel = channel
  }
}

public struct CreateConversationResponse: Codable, Sendable {
  public let conversation: Conversation
  public let initialTimelineItems: [TimelineItem]
}

// MARK: - Mark Seen

public struct MarkSeenResponse: Codable, Sendable {
  public let conversationId: String
  public let lastSeenAt: String
}

// MARK: - Typing

public struct SetTypingRequest: Codable, Sendable {
  public let isTyping: Bool
  public let visitorPreview: String?

  public init(isTyping: Bool, visitorPreview: String? = nil) {
    self.isTyping = isTyping
    self.visitorPreview = visitorPreview
  }
}

public struct SetTypingResponse: Codable, Sendable {
  public let conversationId: String
  public let isTyping: Bool
  public let visitorPreview: String?
  public let sentAt: String
}

// MARK: - Rating

public struct SubmitRatingRequest: Codable, Sendable {
  public let rating: Int
  public let comment: String?

  public init(rating: Int, comment: String? = nil) {
    self.rating = rating
    self.comment = comment
  }
}

public struct SubmitRatingResponse: Codable, Sendable {
  public let conversationId: String
  public let rating: Int
  public let ratedAt: String
}
