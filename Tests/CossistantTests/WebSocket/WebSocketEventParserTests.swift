import Testing
import Foundation
@testable import Cossistant

@Suite("WebSocketEventParser")
struct WebSocketEventParserTests {
  @Test("Parses timelineItemCreated")
  func parsesTimelineItemCreated() {
    guard let event = WebSocketEventParser.parse(from: TestFixtures.timelineItemCreatedEvent) else {
      Issue.record("Failed to parse event")
      return
    }

    if case .timelineItemCreated(let payload) = event {
      #expect(payload.conversationId == "conv_001")
      #expect(payload.item.id == "item_ws_001")
      #expect(payload.item.text == "Agent reply via WS")
    } else {
      Issue.record("Expected timelineItemCreated, got \(event)")
    }
  }

  @Test("Parses conversationTyping")
  func parsesConversationTyping() {
    guard let event = WebSocketEventParser.parse(from: TestFixtures.conversationTypingEvent) else {
      Issue.record("Failed to parse event")
      return
    }

    if case .conversationTyping(let payload) = event {
      #expect(payload.conversationId == "conv_001")
      #expect(payload.isTyping == true)
    } else {
      Issue.record("Expected conversationTyping")
    }
  }

  @Test("Parses aiAgentProcessingProgress")
  func parsesAIProgress() {
    guard let event = WebSocketEventParser.parse(from: TestFixtures.aiProgressEvent) else {
      Issue.record("Failed to parse event")
      return
    }

    if case .aiAgentProcessingProgress(let payload) = event {
      #expect(payload.phase == "thinking")
      #expect(payload.message == "Analyzing your question...")
      #expect(payload.aiAgentId == "ai_001")
    } else {
      Issue.record("Expected aiAgentProcessingProgress")
    }
  }

  @Test("Parses conversationCreated")
  func parsesConversationCreated() {
    guard let event = WebSocketEventParser.parse(from: TestFixtures.conversationCreatedEvent) else {
      Issue.record("Failed to parse event")
      return
    }

    if case .conversationCreated(let payload) = event {
      #expect(payload.conversationId == "conv_new")
      #expect(payload.conversation.status == .open)
    } else {
      Issue.record("Expected conversationCreated")
    }
  }

  @Test("Unknown event type returns .unknown")
  func parsesUnknownEvent() {
    let json = """
    { "type": "someFutureEvent", "websiteId": "w1", "organizationId": "o1" }
    """.data(using: .utf8)!

    guard let event = WebSocketEventParser.parse(from: json) else {
      Issue.record("Should parse, not return nil")
      return
    }

    if case .unknown(let type) = event {
      #expect(type == "someFutureEvent")
    } else {
      Issue.record("Expected .unknown")
    }
  }

  @Test("Invalid JSON returns nil")
  func invalidJsonReturnsNil() {
    let garbage = "not json at all".data(using: .utf8)!
    #expect(WebSocketEventParser.parse(from: garbage) == nil)
  }
}
