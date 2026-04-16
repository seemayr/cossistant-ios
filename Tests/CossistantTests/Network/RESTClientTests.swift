import Testing
import Foundation
@testable import Cossistant

/// All tests that use MockURLProtocol live here in a single serialized suite.
@Suite("Mock Network Tests", .serialized)
struct MockNetworkTests {

  let configuration = Configuration(
    apiKey: TestFixtures.testAPIKey,
    origin: TestFixtures.testOrigin
  )

  @MainActor
  private func makeClient(storageKey: String = UUID().uuidString) -> CossistantClient {
    let defaults = UserDefaults(suiteName: storageKey)!
    defaults.removePersistentDomain(forName: storageKey)
    return CossistantClient(
      configuration: configuration,
      restSession: MockURLProtocol.mockSession(),
      storage: VisitorStorage(defaults: defaults, websiteId: storageKey),
      shouldConnectWebSocketOnBootstrap: false
    )
  }

  // MARK: - RESTClient Headers & Errors

  @Test("RESTClient sends correct headers")
  func sendsCorrectHeaders() async throws {
    var capturedRequest: URLRequest?
    MockURLProtocol.requestHandler = { request in
      capturedRequest = request
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
    }

    let client = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let _: PublicWebsiteResponse = try await client.request(.getWebsite)

    #expect(capturedRequest?.value(forHTTPHeaderField: "X-Public-Key") == TestFixtures.testAPIKey)
    #expect(capturedRequest?.value(forHTTPHeaderField: "Origin") == TestFixtures.testOrigin)
    #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
  }

  @Test("RESTClient sends X-Visitor-Id after setVisitorId")
  func sendsVisitorId() async throws {
    var capturedRequest: URLRequest?
    MockURLProtocol.requestHandler = { request in
      capturedRequest = request
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.conversationListResponse)
    }

    let client = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    await client.setVisitorId("vis_test")
    let _: ListConversationsResponse = try await client.request(.listConversations(page: 1, limit: 20))

    #expect(capturedRequest?.value(forHTTPHeaderField: "X-Visitor-Id") == "vis_test")
  }

  @Test("RESTClient throws httpError for non-2xx")
  func throwsHttpError() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, "Forbidden".data(using: .utf8)!)
    }
    let client = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    await #expect(throws: CossistantError.self) {
      let _: PublicWebsiteResponse = try await client.request(.getWebsite)
    }
  }

  @Test("RESTClient throws decodingError for invalid JSON")
  func throwsDecodingError() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "not json".data(using: .utf8)!)
    }
    let client = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    await #expect(throws: CossistantError.self) {
      let _: PublicWebsiteResponse = try await client.request(.getWebsite)
    }
  }

  @Test("RESTClient encodes request body")
  func encodesRequestBody() async throws {
    var capturedBody: Data?
    MockURLProtocol.requestHandler = { request in
      if let body = request.httpBody {
        capturedBody = body
      } else if let stream = request.httpBodyStream {
        stream.open()
        var data = Data()
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
          let n = stream.read(buf, maxLength: 4096)
          if n > 0 { data.append(buf, count: n) }
        }
        stream.close()
        capturedBody = data
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.typingResponse)
    }

    let client = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let body = SetTypingRequest(isTyping: true, visitorPreview: "Hello...")
    let _: SetTypingResponse = try await client.request(.setTyping(conversationId: "c1"), body: body)

    let decoded = try JSONDecoder().decode(SetTypingRequest.self, from: try #require(capturedBody))
    #expect(decoded.isTyping == true)
    #expect(decoded.visitorPreview == "Hello...")
  }

  // MARK: - CossistantClient.bootstrap()

  @Test("Bootstrap sets website, visitorId, and connects WS")
  @MainActor
  func bootstrapSetsState() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
    }
    // Test through REST client directly since CossistantClient.rest is private
    let mockRest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    // We test through the rest client directly since CossistantClient.rest is private
    let response: PublicWebsiteResponse = try await mockRest.request(.getWebsite)
    #expect(response.visitor.id == "01KNGYEKPY4QWWWXTH66QCAS7R")
    #expect(response.name == "help.example.com")
    #expect(response.visitor.isBlocked == false)
  }

  @Test("Bootstrap with blocked visitor throws visitorBlocked")
  @MainActor
  func bootstrapBlockedThrows() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.blockedVisitorWebsiteResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let response: PublicWebsiteResponse = try await rest.request(.getWebsite)
    #expect(response.visitor.isBlocked == true)
  }

  // MARK: - CossistantClient.identify()

  @Test("Identify encodes contact request correctly")
  func identifyEncodesRequest() async throws {
    var capturedPath: String?
    MockURLProtocol.requestHandler = { request in
      capturedPath = request.url?.path
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.identifyResponse)
    }

    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    var metadata = VisitorMetadata()
    metadata["plan"] = "premium"
    let body = IdentifyContactRequest(externalId: "user_123", name: "Max", email: "max@example.com", metadata: metadata)
    let response: IdentifyContactResponse = try await rest.request(.identifyContact, body: body)

    #expect(capturedPath?.contains("/contacts/identify") == true)
    #expect(response.contact.name == "Max")
    #expect(response.visitorId == "vis_001")
  }

  // MARK: - ConversationStore

  @Test("ConversationStore.load populates conversations")
  @MainActor
  func conversationStoreLoad() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.conversationListResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = ConversationStore(rest: rest)
    try await store.load()

    #expect(store.conversations.count == 1)
    #expect(store.conversations[0].id == "conv_001")
    #expect(store.hasMore == false)
    #expect(store.isLoading == false)
  }

  @Test("ConversationStore.loadMore appends page 2")
  @MainActor
  func conversationStoreLoadMore() async throws {
    var callCount = 0
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      let data = callCount == 1 ? TestFixtures.conversationListWithMore : TestFixtures.conversationListPage2
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = ConversationStore(rest: rest)
    try await store.load()
    #expect(store.hasMore == true)
    #expect(store.conversations.count == 1)

    try await store.loadMore()
    #expect(store.conversations.count == 2)
    #expect(store.conversations[1].id == "conv_002")
    #expect(store.hasMore == false)
  }

  @Test("ConversationStore.create inserts at front")
  @MainActor
  func conversationStoreCreate() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.createConversationResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = ConversationStore(rest: rest)
    let response = try await store.create(CreateConversationRequest())
    #expect(response.conversation.id == "conv_new_rest")
    #expect(response.conversation.metadata?["source"] == .string("game_loading"))
    #expect(store.conversations.count == 1)
    #expect(store.conversations[0].id == "conv_new_rest")
  }

  @Test("createConversationAndSend includes conversation metadata in the create request")
  @MainActor
  func createConversationAndSendIncludesConversationMetadata() async throws {
    var capturedCreateRequestBody: [String: Any]?
    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      switch path {
      case _ where path.hasSuffix("/websites"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
      case _ where path == "/v1/conversations" || path.hasSuffix("/conversations"):
        capturedCreateRequestBody = try decodeRequestBodyJSON(
          from: request
        )
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.createConversationResponse)
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let client = makeClient()
    try await client.bootstrap()

    let response = try await client.createConversationAndSend(
      text: "I need help",
      visitorId: "vis_001",
      channel: "apple",
      metadata: VisitorMetadata([
        "source": "game_loading",
        "gameId": "game_123"
      ])
    )

    #expect(response.conversation.id == "conv_new_rest")
    let metadata = try #require(capturedCreateRequestBody?["metadata"] as? [String: String])
    let defaultTimelineItems = try #require(
      capturedCreateRequestBody?["defaultTimelineItems"] as? [[String: Any]]
    )
    let firstItem = try #require(defaultTimelineItems.first)

    #expect(metadata["source"] == "game_loading")
    #expect(metadata["gameId"] == "game_123")
    #expect(firstItem["createdAt"] == nil)
  }

  // MARK: - TimelineStore

  @Test("TimelineStore.load populates items")
  @MainActor
  func timelineStoreLoad() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.timelineResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")

    #expect(store.items.count == 2)
    #expect(store.activeConversationId == "conv_001")
    #expect(store.hasMore == false)
  }

  @Test("TimelineStore.loadMore prepends older messages")
  @MainActor
  func timelineStoreLoadMore() async throws {
    var callCount = 0
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      let data = callCount == 1 ? TestFixtures.timelineWithCursor : TestFixtures.timelineOlderPage
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")
    #expect(store.hasMore == true)
    #expect(store.items.count == 1)

    try await store.loadMore()
    #expect(store.items.count == 2)
    #expect(store.items[0].id == "item_very_old") // older prepended
    #expect(store.hasMore == false)
  }

  @Test("TimelineStore.sendMessage creates pending then confirms")
  @MainActor
  func timelineStoreSendMessage() async throws {
    var callCount = 0
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      let data = callCount == 1 ? TestFixtures.timelineResponse : TestFixtures.sendMessageResponse
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")

    try await store.sendMessage(text: "Thanks!", visitorId: "vis_001")
    #expect(store.pendingMessages.isEmpty) // cleared after success
    #expect(store.items.last?.text == "Thanks!")
  }

  @Test("TimelineStore.sendMessage marks pending as failed on error")
  @MainActor
  func timelineStoreSendMessageFails() async throws {
    var callCount = 0
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      if callCount == 1 {
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.timelineResponse)
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, "Server Error".data(using: .utf8)!)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")

    do {
      try await store.sendMessage(text: "Fail", visitorId: "vis_001")
      Issue.record("Should have thrown")
    } catch {
      #expect(store.pendingMessages.count == 1)
      if case .failed = store.pendingMessages[0].status {
        // expected
      } else {
        Issue.record("Expected .failed status")
      }
    }
  }

  @Test("TimelineStore.discardPending removes failed message")
  @MainActor
  func timelineStoreDiscardPending() async throws {
    var callCount = 0
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      if callCount == 1 {
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.timelineResponse)
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, "Error".data(using: .utf8)!)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")
    try? await store.sendMessage(text: "Fail", visitorId: nil)
    #expect(store.pendingMessages.count == 1)

    let pendingId = store.pendingMessages[0].id
    store.discardPending(pendingId: pendingId)
    #expect(store.pendingMessages.isEmpty)
  }

  @Test("TimelineStore.markSeen calls correct endpoint")
  @MainActor
  func timelineStoreMarkSeen() async throws {
    var callCount = 0
    var capturedPath: String?
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      capturedPath = request.url?.path
      let data = callCount == 1 ? TestFixtures.timelineResponse : TestFixtures.markSeenResponse
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")
    try await store.markSeen()
    #expect(capturedPath?.contains("/conversations/conv_001/seen") == true)
  }

  @Test("TimelineStore.submitRating calls correct endpoint")
  @MainActor
  func timelineStoreSubmitRating() async throws {
    var callCount = 0
    var capturedPath: String?
    MockURLProtocol.requestHandler = { request in
      callCount += 1
      capturedPath = request.url?.path
      let data = callCount == 1 ? TestFixtures.timelineResponse : TestFixtures.ratingResponse
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")
    try await store.submitRating(5, comment: "Great!")
    #expect(capturedPath?.contains("/conversations/conv_001/rating") == true)
  }

  @Test("TimelineStore.clear resets all state")
  @MainActor
  func timelineStoreClear() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.timelineResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let store = TimelineStore(rest: rest)
    try await store.load(conversationId: "conv_001")
    #expect(!store.items.isEmpty)

    store.clear()
    #expect(store.items.isEmpty)
    #expect(store.pendingMessages.isEmpty)
    #expect(store.activeConversationId == nil)
    #expect(store.hasMore == false)
  }

  // MARK: - updateMetadata

  @Test("updateMetadata calls correct endpoint with body")
  func updateMetadataCalls() async throws {
    var capturedPath: String?
    MockURLProtocol.requestHandler = { request in
      capturedPath = request.url?.path
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    await rest.setVisitorId("vis_001")
    var metadata = VisitorMetadata()
    metadata["appVersion"] = "2.0"
    try await rest.requestVoid(.updateVisitorMetadata(visitorId: "vis_001"), body: UpdateVisitorMetadataRequest(metadata: metadata))
    #expect(capturedPath?.contains("/visitors/vis_001/metadata") == true)
  }

  @Test("Metadata flush serializes updates while a flush is in flight")
  @MainActor
  func metadataFlushSerializesConcurrentUpdates() async throws {
    let probe = MetadataRequestProbe(blockFirstRequest: true)
    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      switch path {
      case _ where path.hasSuffix("/websites"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
      case _ where path.hasSuffix("/contacts/identify"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.identifyResponse)
      case _ where path.contains("/visitors/") && path.hasSuffix("/metadata"):
        let body = try decodeRequestBody(
          UpdateVisitorMetadataRequest.self,
          from: request
        )
        probe.recordStart(body.metadata)
        defer { probe.recordFinish() }
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let client = makeClient()
    client.setIdentity(externalId: "user_123")
    try await client.bootstrap()

    client.updateMetadata(VisitorMetadata(["plan": "starter"]))
    try await waitUntil {
      probe.requestCount == 1
    }

    client.updateMetadata(VisitorMetadata(["source": "support"]))
    probe.releaseBlockedRequest()

    try await waitUntil {
      probe.requestCount == 2
    }

    #expect(probe.maxConcurrentRequests == 1)
    #expect(probe.requests[0]["plan"] == .string("starter"))
    #expect(probe.requests[1]["plan"] == .string("starter"))
    #expect(probe.requests[1]["source"] == .string("support"))
  }

  @Test("Latest value wins when the same metadata key changes during an in-flight flush")
  @MainActor
  func metadataLatestValueWinsAcrossSerializedFlushes() async throws {
    let probe = MetadataRequestProbe(blockFirstRequest: true)
    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      switch path {
      case _ where path.hasSuffix("/websites"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
      case _ where path.hasSuffix("/contacts/identify"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.identifyResponse)
      case _ where path.contains("/visitors/") && path.hasSuffix("/metadata"):
        let body = try decodeRequestBody(
          UpdateVisitorMetadataRequest.self,
          from: request
        )
        probe.recordStart(body.metadata)
        defer { probe.recordFinish() }
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let client = makeClient()
    client.setIdentity(externalId: "user_123")
    try await client.bootstrap()

    client.updateMetadata(VisitorMetadata(["groupId": "group_a"]))
    try await waitUntil {
      probe.requestCount == 1
    }

    client.updateMetadata(VisitorMetadata(["groupId": "group_b"]))
    probe.releaseBlockedRequest()

    try await waitUntil {
      probe.requestCount == 2
    }

    #expect(probe.requests[0]["groupId"] == .string("group_a"))
    #expect(probe.requests[1]["groupId"] == .string("group_b"))
  }

  @Test("Failed metadata flush stays queued until a later retry trigger succeeds")
  @MainActor
  func failedMetadataFlushIsRetriedLater() async throws {
    let probe = MetadataRequestProbe()
    var patchAttempt = 0
    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      switch path {
      case _ where path.hasSuffix("/websites"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
      case _ where path.hasSuffix("/contacts/identify"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.identifyResponse)
      case _ where path.contains("/visitors/") && path.hasSuffix("/metadata"):
        patchAttempt += 1
        let body = try decodeRequestBody(
          UpdateVisitorMetadataRequest.self,
          from: request
        )
        probe.recordStart(body.metadata)
        defer { probe.recordFinish() }
        if patchAttempt == 1 {
          return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, "Server Error".data(using: .utf8)!)
        }
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let client = makeClient()
    client.setIdentity(externalId: "user_123")
    try await client.bootstrap()

    client.updateMetadata(VisitorMetadata(["plan": "starter"]))
    try await waitUntil {
      probe.requestCount == 1
    }

    try await client.identify(externalId: "user_123")
    try await waitUntil {
      probe.requestCount == 2
    }

    #expect(probe.requests[0] == VisitorMetadata(["plan": "starter"]))
    #expect(probe.requests[1] == VisitorMetadata(["plan": "starter"]))
  }

  @Test("Anonymous metadata stays queued until identification succeeds")
  @MainActor
  func anonymousMetadataQueuesUntilIdentification() async throws {
    let probe = MetadataRequestProbe()
    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      switch path {
      case _ where path.hasSuffix("/websites"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
      case _ where path.hasSuffix("/contacts/identify"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.identifyResponse)
      case _ where path.contains("/visitors/") && path.hasSuffix("/metadata"):
        let body = try decodeRequestBody(
          UpdateVisitorMetadataRequest.self,
          from: request
        )
        probe.recordStart(body.metadata)
        defer { probe.recordFinish() }
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let client = makeClient()
    try await client.bootstrap()

    client.updateMetadata(VisitorMetadata(["plan": "starter"]))
    try await Task.sleep(for: .milliseconds(50))
    #expect(probe.requestCount == 0)

    client.updateMetadata(VisitorMetadata(["source": "game"]))
    try await Task.sleep(for: .milliseconds(50))
    #expect(probe.requestCount == 0)

    try await client.identify(externalId: "user_123")
    try await waitUntil {
      probe.requestCount == 1
    }

    #expect(probe.requests[0]["plan"] == .string("starter"))
    #expect(probe.requests[0]["source"] == .string("game"))
  }

  @Test("Queued metadata flushes exactly once after bootstrap auto-identify")
  @MainActor
  func queuedMetadataFlushesOnceAfterBootstrapIdentify() async throws {
    let probe = MetadataRequestProbe()
    var identifyCount = 0
    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      switch path {
      case _ where path.hasSuffix("/websites"):
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.websiteResponse)
      case _ where path.hasSuffix("/contacts/identify"):
        identifyCount += 1
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.identifyResponse)
      case _ where path.contains("/visitors/") && path.hasSuffix("/metadata"):
        let body = try decodeRequestBody(
          UpdateVisitorMetadataRequest.self,
          from: request
        )
        probe.recordStart(body.metadata)
        defer { probe.recordFinish() }
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let client = makeClient()
    client.setIdentity(externalId: "user_123")
    client.updateMetadata(VisitorMetadata(["plan": "starter"]))

    try await client.bootstrap()
    try await waitUntil {
      probe.requestCount == 1
    }

    #expect(identifyCount == 1)
    #expect(probe.requestCount == 1)
    #expect(probe.requests[0]["plan"] == .string("starter"))
  }

  // MARK: - Activity Tracking

  @Test("Activity tracking calls correct endpoint")
  func activityTracking() async throws {
    var capturedPath: String?
    MockURLProtocol.requestHandler = { request in
      capturedPath = request.url?.path
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.activityResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let body = VisitorActivityRequest(sessionId: "sess_001", activityType: "heartbeat")
    try await rest.requestVoid(.visitorActivity, body: body)
    #expect(capturedPath?.contains("/visitors/activity") == true)
  }

  // MARK: - File Upload URL

  @Test("Generate upload URL decodes response")
  func generateUploadURL() async throws {
    MockURLProtocol.requestHandler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, TestFixtures.uploadURLResponse)
    }
    let rest = RESTClient(configuration: configuration, session: MockURLProtocol.mockSession())
    let body = GenerateUploadURLRequest(
      contentType: "application/pdf",
      websiteId: "site_001",
      organizationId: "org_001",
      conversationId: "conv_001",
      fileName: "test.pdf"
    )
    let response: GenerateUploadURLResponse = try await rest.request(.generateUploadURL, body: body)
    #expect(response.publicUrl == "https://cdn.example.com/uploads/file.pdf")
    #expect(response.uploadUrl.contains("s3.amazonaws.com"))
  }
}

private final class MetadataRequestProbe: @unchecked Sendable {
  private let lock = NSLock()
  private let firstRequestStarted = DispatchSemaphore(value: 0)
  private let releaseFirstRequest = DispatchSemaphore(value: 0)
  private let blockFirstRequest: Bool

  private var requestsStorage: [VisitorMetadata] = []
  private var requestCountStorage = 0
  private var maxConcurrentRequestsStorage = 0
  private var concurrentRequests = 0

  init(blockFirstRequest: Bool = false) {
    self.blockFirstRequest = blockFirstRequest
  }

  var requests: [VisitorMetadata] {
    lock.withLock { requestsStorage }
  }

  var requestCount: Int {
    lock.withLock { requestCountStorage }
  }

  var maxConcurrentRequests: Int {
    lock.withLock { maxConcurrentRequestsStorage }
  }

  func recordStart(_ metadata: VisitorMetadata) {
    let shouldBlock: Bool = lock.withLock {
      requestCountStorage += 1
      concurrentRequests += 1
      maxConcurrentRequestsStorage = max(maxConcurrentRequestsStorage, concurrentRequests)
      requestsStorage.append(metadata)
      return blockFirstRequest && requestCountStorage == 1
    }

    if shouldBlock {
      firstRequestStarted.signal()
      releaseFirstRequest.wait()
    }
  }

  func recordFinish() {
    lock.withLock {
      concurrentRequests -= 1
    }
  }

  func waitForFirstRequest(timeout: TimeInterval) -> Bool {
    firstRequestStarted.wait(timeout: .now() + timeout) == .success
  }

  func releaseBlockedRequest() {
    releaseFirstRequest.signal()
  }
}

private func decodeRequestBody<T: Decodable>(
  _ type: T.Type,
  from request: URLRequest
) throws -> T {
  let data = try requestBodyData(from: request)
  return try JSONDecoder().decode(T.self, from: data)
}

private func decodeRequestBodyJSON(
  from request: URLRequest
) throws -> [String: Any] {
  let data = try requestBodyData(from: request)
  let json = try JSONSerialization.jsonObject(with: data)
  guard let dictionary = json as? [String: Any] else {
    throw URLError(.cannotParseResponse)
  }
  return dictionary
}

private func requestBodyData(from request: URLRequest) throws -> Data {
  let data: Data
  if let body = request.httpBody {
    data = body
  } else if let stream = request.httpBodyStream {
    stream.open()
    defer { stream.close() }

    var result = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
      let count = stream.read(buffer, maxLength: 4096)
      if count > 0 {
        result.append(buffer, count: count)
      }
    }
    data = result
  } else {
    throw URLError(.badServerResponse)
  }
  return data
}

private func waitUntil(
  timeout: Duration = .seconds(1),
  pollInterval: Duration = .milliseconds(10),
  condition: @escaping @Sendable () -> Bool
) async throws {
  let deadline = ContinuousClock.now + timeout
  while !condition() {
    if ContinuousClock.now >= deadline {
      throw URLError(.timedOut)
    }
    try await Task.sleep(for: pollInterval)
  }
}

private extension NSLock {
  func withLock<T>(_ body: () -> T) -> T {
    lock()
    defer { unlock() }
    return body()
  }
}
