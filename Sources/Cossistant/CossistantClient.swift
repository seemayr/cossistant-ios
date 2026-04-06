import Foundation

/// Main entry point for the Cossistant SDK.
/// MainActor-isolated so it can create and hold @MainActor stores.
@MainActor
public final class CossistantClient {
  /// Observable store for conversations.
  public let conversations: ConversationStore

  /// Observable store for timeline items (messages).
  public let timeline: TimelineStore

  /// Observable store for connection state, typing indicators, and AI processing.
  public let connection: ConnectionStore

  /// Agent registry for resolving userId/aiAgentId → name, image, online status.
  public let agents: AgentRegistry

  /// The SDK configuration.
  public nonisolated let configuration: Configuration

  private let rest: RESTClient
  private let webSocket: WebSocketClient
  private let storage: VisitorStorage

  /// Website info returned from bootstrap.
  public private(set) var website: PublicWebsiteResponse?

  /// The current visitor ID.
  public private(set) var visitorId: String?

  public init(configuration: Configuration) {
    self.configuration = configuration
    self.rest = RESTClient(configuration: configuration)
    self.storage = VisitorStorage()

    let agentRegistry = AgentRegistry()
    let conversationStore = ConversationStore(rest: rest)
    let timelineStore = TimelineStore(rest: rest)
    let connectionStore = ConnectionStore(agents: agentRegistry)

    self.agents = agentRegistry
    self.conversations = conversationStore
    self.timeline = timelineStore
    self.connection = connectionStore

    self.webSocket = WebSocketClient(
      configuration: configuration,
      onEvent: { [weak conversationStore, weak timelineStore, weak connectionStore] event in
        guard let conversations = conversationStore,
              let timeline = timelineStore,
              let connection = connectionStore else { return }

        switch event {
        case .conversationCreated(let payload):
          conversations.handleConversationCreated(payload)
        case .conversationUpdated(let payload):
          conversations.handleConversationUpdated(payload)
        case .conversationTyping(let payload):
          connection.handleTyping(payload)
        case .timelineItemCreated(let payload):
          timeline.handleTimelineItemCreated(payload)
        case .timelineItemUpdated(let payload):
          timeline.handleTimelineItemUpdated(payload)
        case .aiAgentProcessingProgress(let payload):
          connection.handleAIProgress(payload)
        case .aiAgentProcessingCompleted(let payload):
          connection.handleAICompleted(payload)
        case .conversationSeen(let payload):
          connection.handleSeen(payload)
        case .visitorIdentified, .connectionEstablished, .unknown:
          break
        }
      },
      onConnectionChange: { [weak connectionStore] isConnected in
        connectionStore?.setConnected(isConnected)
      }
    )
  }

  // MARK: - Bootstrap

  /// Initializes the SDK: fetches website config, creates/retrieves visitor, connects WebSocket.
  public func bootstrap() async throws {
    SupportLogger.bootstrapStarted()

    // Restore visitor ID from storage if available
    if let stored = storage.visitorId {
      await rest.setVisitorId(stored)
    }

    let response: PublicWebsiteResponse = try await rest.request(.getWebsite)
    website = response
    visitorId = response.visitor.id
    agents.populate(from: response)

    // Persist visitor ID
    storage.visitorId = response.visitor.id
    await rest.setVisitorId(response.visitor.id)

    // Check if visitor is blocked
    guard !response.visitor.isBlocked else {
      SupportLogger.bootstrapFailed(CossistantError.visitorBlocked)
      throw CossistantError.visitorBlocked
    }

    SupportLogger.bootstrapSuccess(visitorId: response.visitor.id, websiteId: response.id)

    // Connect WebSocket
    await webSocket.connect(visitorId: response.visitor.id)
  }

  // MARK: - Identify

  /// Links the current visitor to a contact with metadata.
  public func identify(
    externalId: String? = nil,
    email: String? = nil,
    name: String? = nil,
    image: String? = nil,
    metadata: VisitorMetadata? = nil
  ) async throws {
    let request = IdentifyContactRequest(
      visitorId: visitorId,
      externalId: externalId,
      name: name,
      email: email,
      image: image,
      metadata: metadata
    )
    let _: IdentifyContactResponse = try await rest.request(
      .identifyContact, body: request
    )
  }

  /// Updates the visitor's metadata (merge, not replace).
  public func updateMetadata(_ metadata: VisitorMetadata) async throws {
    guard let visitorId else { throw CossistantError.notBootstrapped }
    let request = UpdateVisitorMetadataRequest(metadata: metadata)
    try await rest.requestVoid(.updateVisitorMetadata(visitorId: visitorId), body: request)
  }

  // MARK: - File Upload

  /// Uploads a file and returns the hosted URL to attach to a message.
  /// 1. Gets a presigned S3 URL from the API
  /// 2. PUTs the file data to S3
  /// 3. Returns the public file URL
  public func uploadFile(
    data: Data,
    fileName: String,
    contentType: String,
    conversationId: String
  ) async throws -> String {
    let request = GenerateUploadURLRequest(
      fileName: fileName,
      contentType: contentType,
      conversationId: conversationId
    )
    let response: GenerateUploadURLResponse = try await rest.request(
      .generateUploadURL, body: request
    )

    // PUT to S3
    guard let uploadURL = URL(string: response.url) else {
      throw CossistantError.networkError(underlying: URLError(.badURL))
    }
    var s3Request = URLRequest(url: uploadURL)
    s3Request.httpMethod = "PUT"
    s3Request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    s3Request.httpBody = data

    let (_, s3Response) = try await URLSession.shared.data(for: s3Request)
    guard let httpResponse = s3Response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
      throw CossistantError.httpError(
        statusCode: (s3Response as? HTTPURLResponse)?.statusCode ?? 0,
        body: nil
      )
    }

    return response.fileUrl
  }

  // MARK: - Activity Tracking

  /// Sends a visitor activity event (heartbeat, focus, etc.).
  public func sendActivity(
    sessionId: String,
    activityType: String = "heartbeat"
  ) async throws {
    let request = VisitorActivityRequest(
      sessionId: sessionId,
      activityType: activityType
    )
    try await rest.requestVoid(.visitorActivity, body: request)
  }

  // MARK: - Disconnect

  /// Disconnects the WebSocket. Call when the support UI is dismissed.
  public func disconnect() async {
    await webSocket.disconnect()
  }
}
