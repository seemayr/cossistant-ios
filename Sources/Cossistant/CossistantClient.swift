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

    let conversationStore = ConversationStore(rest: rest)
    let timelineStore = TimelineStore(rest: rest)
    let connectionStore = ConnectionStore()

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
        case .conversationSeen, .visitorIdentified, .connectionEstablished, .unknown:
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
    // Restore visitor ID from storage if available
    if let stored = storage.visitorId {
      await rest.setVisitorId(stored)
    }

    let response: PublicWebsiteResponse = try await rest.request(.getWebsite)
    website = response
    visitorId = response.visitor.id

    // Persist visitor ID
    storage.visitorId = response.visitor.id
    await rest.setVisitorId(response.visitor.id)

    // Check if visitor is blocked
    guard !response.visitor.isBlocked else {
      throw CossistantError.visitorBlocked
    }

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

  // MARK: - Disconnect

  /// Disconnects the WebSocket. Call when the support UI is dismissed.
  public func disconnect() async {
    await webSocket.disconnect()
  }
}
