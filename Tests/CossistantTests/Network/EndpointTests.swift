import Testing
import Foundation
@testable import Cossistant

@Suite("Endpoint")
struct EndpointTests {
  @Test("GET /websites")
  func getWebsite() {
    let ep = Endpoint.getWebsite
    #expect(ep.method == "GET")
    #expect(ep.path == "/websites")
    #expect(ep.queryItems == nil)
  }

  @Test("GET /conversations with pagination")
  func listConversations() {
    let ep = Endpoint.listConversations(page: 2, limit: 10)
    #expect(ep.method == "GET")
    #expect(ep.path == "/conversations")
    let items = ep.queryItems!
    #expect(items.contains(URLQueryItem(name: "page", value: "2")))
    #expect(items.contains(URLQueryItem(name: "limit", value: "10")))
  }

  @Test("GET /conversations/{id}/timeline with cursor")
  func getTimeline() {
    let ep = Endpoint.getTimeline(conversationId: "abc", limit: 50, cursor: "cursor_123")
    #expect(ep.method == "GET")
    #expect(ep.path == "/conversations/abc/timeline")
    let items = ep.queryItems!
    #expect(items.contains(URLQueryItem(name: "limit", value: "50")))
    #expect(items.contains(URLQueryItem(name: "cursor", value: "cursor_123")))
  }

  @Test("GET /conversations/{id}/timeline without cursor")
  func getTimelineNoCursor() {
    let ep = Endpoint.getTimeline(conversationId: "abc", limit: 20, cursor: nil)
    let items = ep.queryItems!
    #expect(!items.contains(where: { $0.name == "cursor" }))
  }

  @Test("POST endpoints")
  func postEndpoints() {
    #expect(Endpoint.createConversation.method == "POST")
    #expect(Endpoint.sendMessage.method == "POST")
    #expect(Endpoint.identifyContact.method == "POST")
    #expect(Endpoint.submitRating(conversationId: "x").method == "POST")
    #expect(Endpoint.generateUploadURL.method == "POST")
    #expect(Endpoint.visitorActivity.method == "POST")
  }

  @Test("PATCH endpoints")
  func patchEndpoints() {
    #expect(Endpoint.markSeen(conversationId: "x").method == "PATCH")
    #expect(Endpoint.setTyping(conversationId: "x").method == "PATCH")
    #expect(Endpoint.updateVisitorMetadata(visitorId: "v1").method == "PATCH")
  }

  @Test("Paths include IDs correctly")
  func pathsIncludeIds() {
    #expect(Endpoint.getConversation(id: "conv_42").path == "/conversations/conv_42")
    #expect(Endpoint.markSeen(conversationId: "c1").path == "/conversations/c1/seen")
    #expect(Endpoint.setTyping(conversationId: "c2").path == "/conversations/c2/typing")
    #expect(Endpoint.submitRating(conversationId: "c3").path == "/conversations/c3/rating")
    #expect(Endpoint.updateVisitorMetadata(visitorId: "v1").path == "/visitors/v1/metadata")
    #expect(Endpoint.visitorActivity.path == "/visitors/activity")
    #expect(Endpoint.generateUploadURL.path == "/upload/generate-url")
  }
}
