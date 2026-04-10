import Foundation

/// JSON fixtures matching real Cossistant API responses.
enum TestFixtures {
  static let testAPIKey = ProcessInfo.processInfo.environment["COSSISTANT_TEST_API_KEY"]
    ?? "pk_test_placeholder_for_unit_tests"
  static let testOrigin = "http://localhost:3000"

  static let websiteResponse = """
  {
    "id": "01KNGRFZ1M977NBY79HWWG6JRY",
    "name": "help.example.com",
    "domain": "help.example.com",
    "description": null,
    "logoUrl": null,
    "organizationId": "01KN8XRSDSSKN46PCK3SHX5XB5",
    "status": "active",
    "lastOnlineAt": "2026-04-06T08:26:58.928Z",
    "availableHumanAgents": [
      {
        "id": "01KN8XRQMTFXECQVN4NDNJWCGY",
        "name": "Test Agent",
        "image": "https://example.com/avatar.png",
        "lastSeenAt": "2026-04-06T08:26:58.928Z"
      }
    ],
    "availableAIAgents": [],
    "visitor": {
      "id": "01KNGYEKPY4QWWWXTH66QCAS7R",
      "isBlocked": false,
      "language": null,
      "contact": null
    }
  }
  """.data(using: .utf8)!

  static let conversationListResponse = """
  {
    "conversations": [
      {
        "id": "conv_001",
        "title": "Test conversation",
        "metadata": { "source": "settings" },
        "createdAt": "2026-04-06T10:00:00.000Z",
        "updatedAt": "2026-04-06T10:05:00.000Z",
        "visitorId": "vis_001",
        "websiteId": "web_001",
        "status": "open",
        "visitorRating": null,
        "visitorRatingAt": null,
        "deletedAt": null,
        "visitorLastSeenAt": null
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 1,
      "totalPages": 1,
      "hasMore": false
    }
  }
  """.data(using: .utf8)!

  static let timelineResponse = """
  {
    "items": [
      {
        "id": "item_001",
        "conversationId": "conv_001",
        "organizationId": "org_001",
        "visibility": "public",
        "type": "message",
        "text": "Hello, how can I help?",
        "tool": null,
        "parts": [
          { "type": "text", "text": "Hello, how can I help?" }
        ],
        "userId": "user_001",
        "aiAgentId": null,
        "visitorId": null,
        "createdAt": "2026-04-06T10:00:00.000Z",
        "deletedAt": null
      },
      {
        "id": "item_002",
        "conversationId": "conv_001",
        "organizationId": "org_001",
        "visibility": "public",
        "type": "message",
        "text": "I need help with billing",
        "tool": null,
        "parts": [
          { "type": "text", "text": "I need help with billing" }
        ],
        "userId": null,
        "aiAgentId": null,
        "visitorId": "vis_001",
        "createdAt": "2026-04-06T10:01:00.000Z",
        "deletedAt": null
      }
    ],
    "nextCursor": null,
    "hasNextPage": false
  }
  """.data(using: .utf8)!

  static let sendMessageResponse = """
  {
    "item": {
      "id": "item_003",
      "conversationId": "conv_001",
      "organizationId": "org_001",
      "visibility": "public",
      "type": "message",
      "text": "Thanks!",
      "tool": null,
      "parts": [{ "type": "text", "text": "Thanks!" }],
      "userId": null,
      "aiAgentId": null,
      "visitorId": "vis_001",
      "createdAt": "2026-04-06T10:02:00.000Z",
      "deletedAt": null
    }
  }
  """.data(using: .utf8)!

  // MARK: - WebSocket Events

  static let timelineItemCreatedEvent = """
  {
    "type": "timelineItemCreated",
    "websiteId": "web_001",
    "organizationId": "org_001",
    "visitorId": "vis_001",
    "userId": null,
    "conversationId": "conv_001",
    "item": {
      "id": "item_ws_001",
      "conversationId": "conv_001",
      "organizationId": "org_001",
      "visibility": "public",
      "type": "message",
      "text": "Agent reply via WS",
      "parts": [{ "type": "text", "text": "Agent reply via WS" }],
      "userId": "user_001",
      "visitorId": null,
      "aiAgentId": null,
      "createdAt": "2026-04-06T10:03:00.000Z",
      "deletedAt": null
    }
  }
  """.data(using: .utf8)!

  static let conversationTypingEvent = """
  {
    "type": "conversationTyping",
    "websiteId": "web_001",
    "organizationId": "org_001",
    "visitorId": null,
    "userId": "user_001",
    "conversationId": "conv_001",
    "isTyping": true,
    "visitorPreview": null,
    "aiAgentId": null
  }
  """.data(using: .utf8)!

  static let aiProgressEvent = """
  {
    "type": "aiAgentProcessingProgress",
    "websiteId": "web_001",
    "organizationId": "org_001",
    "visitorId": null,
    "userId": null,
    "conversationId": "conv_001",
    "aiAgentId": "ai_001",
    "workflowRunId": "wf_001",
    "phase": "thinking",
    "message": "Analyzing your question...",
    "audience": "all"
  }
  """.data(using: .utf8)!

  static let conversationCreatedEvent = """
  {
    "type": "conversationCreated",
    "websiteId": "web_001",
    "organizationId": "org_001",
    "visitorId": "vis_001",
    "userId": null,
    "conversationId": "conv_new",
    "conversation": {
      "id": "conv_new",
      "title": null,
      "createdAt": "2026-04-06T11:00:00.000Z",
      "updatedAt": "2026-04-06T11:00:00.000Z",
      "visitorId": "vis_001",
      "websiteId": "web_001",
      "status": "open",
      "visitorRating": null,
      "visitorRatingAt": null,
      "deletedAt": null,
      "visitorLastSeenAt": null,
      "lastTimelineItem": {
        "id": "tl_agent_001",
        "conversationId": "conv_new",
        "organizationId": "org_001",
        "visibility": "public",
        "type": "message",
        "text": "How can I help?",
        "parts": [{"type": "text", "text": "How can I help?"}],
        "userId": "user_001",
        "aiAgentId": null,
        "visitorId": null,
        "createdAt": "2026-04-06T11:00:00.000Z",
        "deletedAt": null
      }
    }
  }
  """.data(using: .utf8)!

  // MARK: - Additional API Responses

  static let identifyResponse = """
  {
    "contact": {
      "id": "contact_001",
      "externalId": "user_123",
      "name": "Max",
      "email": "max@example.com",
      "image": null,
      "metadata": { "plan": "premium" },
      "contactOrganizationId": null,
      "websiteId": "web_001",
      "organizationId": "org_001",
      "createdAt": "2026-04-06T10:00:00.000Z",
      "updatedAt": "2026-04-06T10:00:00.000Z"
    },
    "visitorId": "vis_001"
  }
  """.data(using: .utf8)!

  static let markSeenResponse = """
  { "conversationId": "conv_001", "lastSeenAt": "2026-04-06T10:05:00.000Z" }
  """.data(using: .utf8)!

  static let typingResponse = """
  { "conversationId": "conv_001", "isTyping": true, "visitorPreview": "Hello...", "sentAt": "2026-04-06T10:05:00.000Z" }
  """.data(using: .utf8)!

  static let ratingResponse = """
  { "conversationId": "conv_001", "rating": 5, "ratedAt": "2026-04-06T10:05:00.000Z" }
  """.data(using: .utf8)!

  static let conversationListPage2 = """
  {
    "conversations": [
      {
        "id": "conv_002",
        "title": "Second conversation",
        "createdAt": "2026-04-05T10:00:00.000Z",
        "updatedAt": "2026-04-05T10:05:00.000Z",
        "visitorId": "vis_001",
        "websiteId": "web_001",
        "status": "resolved",
        "visitorRating": null,
        "visitorRatingAt": null,
        "deletedAt": null,
        "visitorLastSeenAt": null
      }
    ],
    "pagination": { "page": 2, "limit": 20, "total": 2, "totalPages": 2, "hasMore": false }
  }
  """.data(using: .utf8)!

  static let conversationListWithMore = """
  {
    "conversations": [
      {
        "id": "conv_001",
        "title": "Test conversation",
        "createdAt": "2026-04-06T10:00:00.000Z",
        "updatedAt": "2026-04-06T10:05:00.000Z",
        "visitorId": "vis_001",
        "websiteId": "web_001",
        "status": "open",
        "visitorRating": null,
        "visitorRatingAt": null,
        "deletedAt": null,
        "visitorLastSeenAt": null
      }
    ],
    "pagination": { "page": 1, "limit": 20, "total": 2, "totalPages": 2, "hasMore": true }
  }
  """.data(using: .utf8)!

  static let timelineWithCursor = """
  {
    "items": [
      {
        "id": "item_old",
        "conversationId": "conv_001",
        "organizationId": "org_001",
        "visibility": "public",
        "type": "message",
        "text": "Old message",
        "tool": null,
        "parts": [{ "type": "text", "text": "Old message" }],
        "userId": null,
        "aiAgentId": null,
        "visitorId": "vis_001",
        "createdAt": "2026-04-05T10:00:00.000Z",
        "deletedAt": null
      }
    ],
    "nextCursor": "cursor_abc",
    "hasNextPage": true
  }
  """.data(using: .utf8)!

  static let timelineOlderPage = """
  {
    "items": [
      {
        "id": "item_very_old",
        "conversationId": "conv_001",
        "organizationId": "org_001",
        "visibility": "public",
        "type": "message",
        "text": "Very old message",
        "tool": null,
        "parts": [{ "type": "text", "text": "Very old message" }],
        "userId": "user_001",
        "aiAgentId": null,
        "visitorId": null,
        "createdAt": "2026-04-04T10:00:00.000Z",
        "deletedAt": null
      }
    ],
    "nextCursor": null,
    "hasNextPage": false
  }
  """.data(using: .utf8)!

  static let conversationUpdatedEvent = """
  {
    "type": "conversationUpdated",
    "websiteId": "web_001",
    "organizationId": "org_001",
    "visitorId": null,
    "userId": "user_001",
    "conversationId": "conv_001",
    "updates": { "title": "Billing Question", "status": "resolved" },
    "aiAgentId": null
  }
  """.data(using: .utf8)!

  static let uploadURLResponse = """
  { "uploadUrl": "https://s3.amazonaws.com/bucket/presigned", "publicUrl": "https://cdn.example.com/uploads/file.pdf", "key": "org/site/file.pdf", "bucket": "cossistant-uploads", "expiresAt": "2026-04-06T12:00:00.000Z", "contentType": "application/pdf" }
  """.data(using: .utf8)!

  static let activityResponse = """
  { "ok": true, "acceptedAt": "2026-04-06T10:00:01.000Z" }
  """.data(using: .utf8)!

  static let createConversationResponse = """
  {
    "conversation": {
      "id": "conv_new_rest",
      "title": null,
      "metadata": { "source": "game_loading", "gameId": "game_123" },
      "createdAt": "2026-04-06T12:00:00.000Z",
      "updatedAt": "2026-04-06T12:00:00.000Z",
      "visitorId": "vis_001",
      "websiteId": "web_001",
      "status": "open",
      "visitorRating": null,
      "visitorRatingAt": null,
      "deletedAt": null,
      "visitorLastSeenAt": null
    },
    "initialTimelineItems": []
  }
  """.data(using: .utf8)!

  static let blockedVisitorWebsiteResponse = """
  {
    "id": "web_001", "name": "test", "domain": "test.com", "description": null,
    "logoUrl": null, "organizationId": "org_001", "status": "active",
    "lastOnlineAt": null, "availableHumanAgents": [], "availableAIAgents": [],
    "visitor": { "id": "vis_blocked", "isBlocked": true, "language": null, "contact": null }
  }
  """.data(using: .utf8)!

  // MARK: - Timeline Item Parts (all types)

  static let allPartsTimeline = """
  {
    "items": [
      {
        "id": "item_parts",
        "conversationId": "conv_001",
        "organizationId": "org_001",
        "visibility": "public",
        "type": "message",
        "text": null,
        "tool": null,
        "parts": [
          { "type": "text", "text": "Hello", "state": "done" },
          { "type": "reasoning", "text": "Thinking about this...", "state": "done" },
          { "type": "tool-searchKnowledge", "toolCallId": "tc_1", "toolName": "searchKnowledge", "state": "result", "input": {}, "output": {} },
          { "type": "source-url", "sourceId": "src_1", "url": "https://docs.example.com/help", "title": "Help docs" },
          { "type": "source-document", "sourceId": "src_2", "mediaType": "application/pdf", "title": "Guide", "filename": "guide.pdf" },
          { "type": "step-start" },
          { "type": "file", "url": "https://cdn.example.com/file.pdf", "mediaType": "application/pdf", "filename": "report.pdf", "size": 1024 },
          { "type": "image", "url": "https://cdn.example.com/photo.jpg", "mediaType": "image/jpeg", "width": 800, "height": 600 },
          { "type": "event", "eventType": "resolved", "actorUserId": "user_001", "actorAiAgentId": null, "targetUserId": null, "targetAiAgentId": null, "message": null },
          { "type": "metadata", "source": "widget" },
          { "type": "some-future-type", "data": "unknown" }
        ],
        "userId": null,
        "aiAgentId": "ai_001",
        "visitorId": null,
        "createdAt": "2026-04-06T10:00:00.000Z",
        "deletedAt": null
      }
    ],
    "nextCursor": null,
    "hasNextPage": false
  }
  """.data(using: .utf8)!
}
