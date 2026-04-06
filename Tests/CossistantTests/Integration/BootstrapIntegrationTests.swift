import Testing
import Foundation
@testable import Cossistant

/// Integration tests that hit the real Cossistant API with a test key.
/// These require network access and a valid test API key.
@Suite("Integration: Bootstrap", .tags(.integration))
struct BootstrapIntegrationTests {
  let configuration = Configuration(
    apiKey: TestFixtures.testAPIKey,
    origin: TestFixtures.testOrigin
  )

  @Test("Bootstrap fetches website and creates visitor")
  func bootstrapWorks() async throws {
    let rest = RESTClient(configuration: configuration)
    let response: PublicWebsiteResponse = try await rest.request(.getWebsite)

    #expect(response.name == "help.playus.club")
    #expect(!response.visitor.id.isEmpty)
    #expect(response.visitor.isBlocked == false)
    #expect(response.status == "active")
  }

  @Test("Conversation list returns without error")
  func listConversations() async throws {
    let rest = RESTClient(configuration: configuration)

    // Bootstrap first to get visitor ID
    let website: PublicWebsiteResponse = try await rest.request(.getWebsite)
    await rest.setVisitorId(website.visitor.id)

    let response: ListConversationsResponse = try await rest.request(
      .listConversations(page: 1, limit: 10)
    )
    // May be empty, but should not fail
    #expect(response.pagination.page == 1)
  }

  @Test("Create conversation and send message (visible in dashboard)")
  func createConversationAndSendMessage() async throws {
    let rest = RESTClient(configuration: configuration)

    // 1. Bootstrap
    let website: PublicWebsiteResponse = try await rest.request(.getWebsite)
    await rest.setVisitorId(website.visitor.id)

    // 2. Identify visitor with metadata
    let identifyRequest = IdentifyContactRequest(
      visitorId: website.visitor.id,
      externalId: "swift-sdk-test",
      name: "SDK Integration Test",
      email: "test@playus.club",
      metadata: VisitorMetadata([
        "appVersion": .string("1.0.0"),
        "device": .string("Mac (test runner)"),
        "source": .string("swift-test"),
        "sdkVersion": .string("0.1.0"),
      ])
    )
    let identifyResponse: IdentifyContactResponse = try await rest.request(
      .identifyContact, body: identifyRequest
    )
    #expect(identifyResponse.contact.name == "SDK Integration Test")
    #expect(identifyResponse.contact.email == "test@playus.club")
    #expect(identifyResponse.visitorId == website.visitor.id)

    // 3. Create conversation
    let createRequest = CreateConversationRequest(
      visitorId: website.visitor.id,
      channel: "mobile"
    )
    let createResponse: CreateConversationResponse = try await rest.request(
      .createConversation, body: createRequest
    )
    let conversationId = createResponse.conversation.id
    #expect(!conversationId.isEmpty)
    #expect(createResponse.conversation.status == .open)

    // 3. Send a message
    let messageRequest = SendMessageRequest(
      conversationId: conversationId,
      text: "Hello from Cossistant Swift SDK integration test",
      visitorId: website.visitor.id
    )
    let messageResponse: SendMessageResponse = try await rest.request(
      .sendMessage, body: messageRequest
    )
    #expect(messageResponse.item.text == "Hello from Cossistant Swift SDK integration test")
    #expect(messageResponse.item.conversationId == conversationId)
    #expect(messageResponse.item.visitorId == website.visitor.id)
  }
}

extension Tag {
  @Tag static var integration: Self
}
