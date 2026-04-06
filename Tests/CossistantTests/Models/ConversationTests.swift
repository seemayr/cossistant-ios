import Testing
import Foundation
@testable import Cossistant

@Suite("Conversation Model")
struct ConversationTests {
  let decoder = JSONDecoder()

  @Test("Decodes conversation list response")
  func decodesConversationList() throws {
    let response = try decoder.decode(
      ListConversationsResponse.self,
      from: TestFixtures.conversationListResponse
    )
    #expect(response.conversations.count == 1)
    #expect(response.conversations[0].id == "conv_001")
    #expect(response.conversations[0].status == .open)
    #expect(response.conversations[0].title == "Test conversation")
    #expect(response.pagination.hasMore == false)
    #expect(response.pagination.total == 1)
  }

  @Test("Decodes website bootstrap response")
  func decodesWebsiteResponse() throws {
    let response = try decoder.decode(
      PublicWebsiteResponse.self,
      from: TestFixtures.websiteResponse
    )
    #expect(response.name == "help.playus.club")
    #expect(response.status == "active")
    #expect(response.availableHumanAgents.count == 1)
    #expect(response.availableHumanAgents[0].name == "Askus Support")
    #expect(response.availableAIAgents.isEmpty)
    #expect(response.visitor.id == "01KNGYEKPY4QWWWXTH66QCAS7R")
    #expect(response.visitor.isBlocked == false)
  }

  @Test("Decodes timeline response with messages")
  func decodesTimelineResponse() throws {
    let response = try decoder.decode(
      TimelineResponse.self,
      from: TestFixtures.timelineResponse
    )
    #expect(response.items.count == 2)
    #expect(response.items[0].text == "Hello, how can I help?")
    #expect(response.items[0].userId == "user_001")
    #expect(response.items[1].visitorId == "vis_001")
    #expect(response.hasNextPage == false)
    #expect(response.nextCursor == nil)
  }

  @Test("ConversationStatus enum values match API")
  func conversationStatusValues() throws {
    let json = """
    { "id": "c1", "createdAt": "2026-01-01T00:00:00Z", "updatedAt": "2026-01-01T00:00:00Z",
      "visitorId": "v1", "websiteId": "w1", "status": "resolved", "deletedAt": null }
    """.data(using: .utf8)!
    let conv = try decoder.decode(Conversation.self, from: json)
    #expect(conv.status == .resolved)
  }
}
