import Foundation
import ULID

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
  private let shouldConnectWebSocketOnBootstrap: Bool
  private var pendingIdentity: PendingIdentity?
  private var isVisitorIdentified = false
  private var metadataFlushState = MetadataFlushState()

  /// Called on the main actor when the visitor sends a message. Receives the plain text.
  public var onMessageSent: ((_ text: String) -> Void)?

  /// Called on the main actor when a new message from an agent (human or AI) arrives via WebSocket.
  /// Only fires for public messages of type `.message` — tool calls, events, and identification items are excluded.
  public var onMessageReceived: ((_ message: ReceivedMessage) -> Void)?

  /// Called on the main actor when the visitor submits a rating for a resolved conversation.
  public var onConversationRated: ((_ rating: Int) -> Void)?

  /// Website info returned from bootstrap.
  public private(set) var website: PublicWebsiteResponse?

  /// The current visitor ID.
  public private(set) var visitorId: String?

  public convenience init(configuration: Configuration) {
    self.init(
      configuration: configuration,
      restSession: .shared,
      storage: VisitorStorage(),
      shouldConnectWebSocketOnBootstrap: true
    )
  }

  init(
    configuration: Configuration,
    restSession: URLSession,
    storage: VisitorStorage,
    shouldConnectWebSocketOnBootstrap: Bool
  ) {
    self.configuration = configuration
    self.rest = RESTClient(configuration: configuration, session: restSession)
    self.storage = storage
    self.shouldConnectWebSocketOnBootstrap = shouldConnectWebSocketOnBootstrap

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
          conversations.handleConversationSeen(payload)
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

  // MARK: - Incoming Message Notification

  private func notifyMessageReceivedIfNeeded(_ item: TimelineItem) {
    guard onMessageReceived != nil else { return }
    guard item.type == .message, item.visibility == .public else { return }

    // Only fire for non-visitor senders (agent or AI)
    let isFromVisitor = item.visitorId != nil && !(item.visitorId?.isEmpty ?? true)
    guard !isFromVisitor else { return }

    onMessageReceived?(ReceivedMessage(item: item))
  }

  // MARK: - Bootstrap

  /// Initializes the SDK: fetches website config, creates/retrieves visitor, connects WebSocket.
  public func bootstrap() async throws {
    // Wire up message callback (deferred from init to avoid referencing self before fully initialized)
    if timeline.onMessageSent == nil {
      timeline.onMessageSent = { [weak self] text in
        self?.onMessageSent?(text)
      }
    }
    if timeline.onItemCreated == nil {
      timeline.onItemCreated = { [weak self] item in
        self?.notifyMessageReceivedIfNeeded(item)
      }
    }
    if timeline.onConversationRated == nil {
      timeline.onConversationRated = { [weak self] rating in
        self?.onConversationRated?(rating)
      }
    }
    SupportLogger.bootstrapStarted()

    // Restore visitor ID from storage if available
    if let stored = storage.visitorId {
      await rest.setVisitorId(stored)
    }

    let response: PublicWebsiteResponse = try await rest.request(.getWebsite)
    website = response
    visitorId = response.visitor.id
    isVisitorIdentified = response.visitor.contact != nil
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

    // Auto-identify if identity was pre-configured via setIdentity()
    if let identity = pendingIdentity {
      do {
        try await identify(
          externalId: identity.externalId,
          email: identity.email,
          name: identity.name,
          image: identity.image,
          metadata: identity.metadata
        )
        if pendingIdentity == identity {
          pendingIdentity = nil
        }
      } catch {
        SupportLogger.identifyFailed(error)
      }
    }

    if isVisitorIdentified {
      startMetadataFlushIfPossible()
    }

    // Connect WebSocket
    if shouldConnectWebSocketOnBootstrap {
      await webSocket.connect(visitorId: response.visitor.id)
    }
  }

  // MARK: - Identity

  /// Configures visitor identity. Works regardless of bootstrap state:
  /// - **Before bootstrap:** stores the identity locally; it is sent automatically during the next ``bootstrap()`` call.
  /// - **After bootstrap:** sends the identity to the server immediately.
  ///
  /// Safe to call multiple times — the server upserts by `externalId`.
  /// If the immediate identify call fails, the error is logged but not thrown.
  ///
  /// - Parameters:
  ///   - externalId: Your app's user ID.
  ///   - email: The user's email address.
  ///   - name: The user's display name.
  ///   - image: A URL string pointing to the user's avatar image.
  ///   - metadata: Additional key-value metadata to attach to the contact.
  public func setIdentity(
    externalId: String? = nil,
    email: String? = nil,
    name: String? = nil,
    image: String? = nil,
    metadata: VisitorMetadata? = nil
  ) {
    pendingIdentity = PendingIdentity(
      externalId: externalId, email: email,
      name: name, image: image, metadata: metadata
    )

    // If already bootstrapped, identify immediately
    if visitorId != nil {
      Task {
        do {
          try await identify(
            externalId: externalId, email: email,
            name: name, image: image, metadata: metadata
          )
        } catch {
          SupportLogger.identifyFailed(error)
        }
      }
    }
  }

  /// Clears any pending identity and queued metadata. Call on logout before creating a new client.
  public func clearIdentity() {
    pendingIdentity = nil
    isVisitorIdentified = false
    metadataFlushState.reset()
    visitorId = nil
    storage.visitorId = nil
    Task {
      await rest.clearVisitorId()
    }
  }

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
    let response: IdentifyContactResponse = try await rest.request(
      .identifyContact, body: request
    )
    isVisitorIdentified = true
    SupportLogger.identifySuccess(contactId: response.contact.id)
    startMetadataFlushIfPossible()
  }

  public func prepareSupportContact(
    identity: SupportIdentity?,
    metadata: VisitorMetadata = VisitorMetadata()
  ) async -> SupportPreparationReport {
    if let identity {
      do {
        try await identify(
          externalId: identity.externalId,
          email: identity.email,
          name: identity.name,
          image: identity.image,
          metadata: metadata.storage.isEmpty ? nil : metadata
        )
        return SupportPreparationReport()
      } catch {
        SupportLogger.identifyFailed(error)
        return SupportPreparationReport(issues: [
          SupportPreparationIssue(
            step: .identification,
            technicalDetails: error.localizedDescription
          )
        ])
      }
    }

    guard !metadata.storage.isEmpty else {
      return SupportPreparationReport()
    }

    do {
      let targetRevision = mergePendingMetadata(metadata)
      try await flushMetadataThroughRevision(
        targetRevision,
        requireIdentifiedVisitor: true
      )
      return SupportPreparationReport()
    } catch {
      SupportLogger.storeError("Client", action: "prepareSupportContact", error: error)
      return SupportPreparationReport(issues: [
        SupportPreparationIssue(
          step: .contactMetadata,
          technicalDetails: error.localizedDescription
        )
      ])
    }
  }

  public func prepareSupportConversationContext(
    _ metadata: VisitorMetadata
  ) async -> SupportPreparationReport {
    guard !metadata.storage.isEmpty else {
      return SupportPreparationReport()
    }

    do {
      let targetRevision = mergePendingMetadata(metadata)
      try await flushMetadataThroughRevision(
        targetRevision,
        requireIdentifiedVisitor: true
      )
      return SupportPreparationReport()
    } catch {
      SupportLogger.storeError("Client", action: "prepareSupportConversationContext", error: error)
      return SupportPreparationReport(issues: [
        SupportPreparationIssue(
          step: .conversationContext,
          technicalDetails: error.localizedDescription
        )
      ])
    }
  }

  /// Updates the visitor's metadata (merge, not replace). Works regardless of bootstrap state:
  /// - **Before bootstrap:** queues metadata locally; flushed automatically during ``bootstrap()``.
  /// - **After bootstrap:** sends to the server immediately.
  ///
  /// Each call merges into the pending metadata — keys from later calls overwrite earlier ones.
  public func updateMetadata(_ metadata: VisitorMetadata) {
    _ = mergePendingMetadata(metadata)
    startMetadataFlushIfPossible()
  }

  private func startMetadataFlushIfPossible() {
    guard visitorId != nil,
          isVisitorIdentified,
          metadataFlushState.pendingMetadata != nil else {
      return
    }
    let task = makeMetadataFlushTaskIfNeeded()
    Task { @MainActor [weak self] in
      do {
        try await task.value
      } catch {
        guard let self, self.metadataFlushState.lastFlushError != nil else { return }
        SupportLogger.storeError("Client", action: "updateMetadata", error: error)
      }
    }
  }

  private func makeMetadataFlushTaskIfNeeded() -> Task<Void, Error> {
    if let activeFlushTask = metadataFlushState.activeFlushTask {
      return activeFlushTask
    }

    metadataFlushState.lastFlushError = nil
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      defer { self.metadataFlushState.activeFlushTask = nil }
      try await self.runMetadataFlushLoop()
    }
    metadataFlushState.activeFlushTask = task
    return task
  }

  private func runMetadataFlushLoop() async throws {
    while let visitorId,
          isVisitorIdentified,
          let metadata = metadataFlushState.pendingMetadata {
      let revision = metadataFlushState.metadataRevision
      let request = UpdateVisitorMetadataRequest(metadata: metadata)

      do {
        try await rest.requestVoid(.updateVisitorMetadata(visitorId: visitorId), body: request)
      } catch {
        metadataFlushState.lastFlushError = error
        throw error
      }

      metadataFlushState.lastFlushError = nil
      metadataFlushState.flushedMetadataRevision = max(
        metadataFlushState.flushedMetadataRevision,
        revision
      )

      if metadataFlushState.pendingMetadata == metadata {
        metadataFlushState.pendingMetadata = nil
      }
    }
  }

  private func flushMetadataThroughRevision(
    _ targetRevision: Int,
    requireIdentifiedVisitor: Bool
  ) async throws {
    while metadataFlushState.flushedMetadataRevision < targetRevision {
      guard visitorId != nil else {
        throw CossistantError.notBootstrapped
      }
      guard isVisitorIdentified else {
        if requireIdentifiedVisitor {
          throw CossistantError.visitorNotIdentified
        }
        return
      }
      guard metadataFlushState.pendingMetadata != nil else {
        if let lastFlushError = metadataFlushState.lastFlushError {
          throw lastFlushError
        }
        return
      }

      let task = makeMetadataFlushTaskIfNeeded()
      try await task.value
    }
  }

  @discardableResult
  private func mergePendingMetadata(_ metadata: VisitorMetadata) -> Int {
    metadataFlushState.merge(metadata)
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
    guard let website else { throw CossistantError.notBootstrapped }

    let request = GenerateUploadURLRequest(
      contentType: contentType,
      websiteId: website.id,
      organizationId: website.organizationId,
      conversationId: conversationId,
      fileName: fileName
    )
    let response: GenerateUploadURLResponse = try await rest.request(
      .generateUploadURL, body: request
    )

    // PUT to S3
    guard let uploadURL = URL(string: response.uploadUrl) else {
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

    return response.publicUrl
  }

  // MARK: - Send Message with Attachments

  /// Sends a message with text and/or file attachments.
  /// Shows a pending message immediately, uploads files in parallel,
  /// builds parts array, sends as a single message, then reconciles.
  public func sendMessageWithAttachments(
    text: String,
    attachments: [FileAttachment],
    visitorId: String?
  ) async throws {
    guard let conversationId = timeline.activeConversationId else {
      throw CossistantError.notBootstrapped
    }

    // 1. Show pending message immediately (before uploads start)
    let localId = "pending_\(UUID().uuidString)"
    let pending = PendingMessage(
      id: localId,
      conversationId: conversationId,
      text: text,
      attachments: attachments,
      createdAt: Date(),
      status: .sending
    )
    timeline.appendPending(pending)

    do {
      // 2. Upload all files in parallel
      let uploadedParts: [TimelineItemPart] = try await withThrowingTaskGroup(
        of: TimelineItemPart.self
      ) { group in
        for attachment in attachments {
          group.addTask {
            let url = try await self.uploadFile(
              data: attachment.data,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
              conversationId: conversationId
            )
            if attachment.isImage {
              return .image(ImagePart(
                url: url, mediaType: attachment.contentType,
                filename: attachment.fileName, size: attachment.fileSizeBytes
              ))
            } else {
              return .file(FilePart(
                url: url, mediaType: attachment.contentType,
                filename: attachment.fileName, size: attachment.fileSizeBytes
              ))
            }
          }
        }
        var parts: [TimelineItemPart] = []
        for try await part in group { parts.append(part) }
        return parts
      }

      // 3. Build parts: always include a text part (API requires text field)
      var allParts: [TimelineItemPart] = [.text(TextPart(text: text))]
      allParts.append(contentsOf: uploadedParts)

      // 4. Send via API
      let request = SendMessageRequest(
        conversationId: conversationId,
        text: text,
        parts: allParts,
        visitorId: visitorId
      )
      let response: SendMessageResponse = try await rest.request(
        .sendMessage, body: request
      )

      // 5. Reconcile: remove pending, add confirmed item
      timeline.removePending(id: localId)
      timeline.appendItemIfNew(response.item)
      onMessageSent?(text)
    } catch {
      // 6. Mark pending as failed so UI shows retry
      timeline.markPendingFailed(id: localId, error: error.localizedDescription)
      throw error
    }
  }

  // MARK: - Create Conversation and Send First Message

  /// Creates a new conversation with the first message bundled into the request.
  /// Used for lazy conversation creation — the conversation is only created on the
  /// server when the visitor actually sends a message.
  public func createConversationAndSend(
    text: String,
    attachments: [FileAttachment] = [],
    visitorId: String?,
    channel: String? = nil
  ) async throws -> CreateConversationResponse {
    guard let website else { throw CossistantError.notBootstrapped }

    let localConversationId = Self.generateConversationId()
    let localId = "pending_\(UUID().uuidString)"
    let pending = PendingMessage(
      id: localId,
      conversationId: localConversationId,
      text: text,
      attachments: attachments,
      createdAt: Date(),
      status: .sending
    )
    timeline.appendPending(pending)

    do {
      // Upload attachments (if any) using the local conversation ID for the S3 scope
      var allParts: [TimelineItemPart] = [.text(TextPart(text: text))]
      if !attachments.isEmpty {
        let uploadedParts: [TimelineItemPart] = try await withThrowingTaskGroup(
          of: TimelineItemPart.self
        ) { group in
          for attachment in attachments {
            group.addTask {
              let url = try await self.uploadFile(
                data: attachment.data,
                fileName: attachment.fileName,
                contentType: attachment.contentType,
                conversationId: localConversationId
              )
              if attachment.isImage {
                return .image(ImagePart(
                  url: url, mediaType: attachment.contentType,
                  filename: attachment.fileName, size: attachment.fileSizeBytes
                ))
              } else {
                return .file(FilePart(
                  url: url, mediaType: attachment.contentType,
                  filename: attachment.fileName, size: attachment.fileSizeBytes
                ))
              }
            }
          }
          var parts: [TimelineItemPart] = []
          for try await part in group { parts.append(part) }
          return parts
        }
        allParts.append(contentsOf: uploadedParts)
      }

      // Bundle the message as a defaultTimelineItem in the create request
      let messageItem = TimelineItem(
        id: ULID().ulidString,
        conversationId: localConversationId,
        organizationId: website.organizationId,
        visibility: .public,
        type: .message,
        text: text,
        tool: nil,
        parts: allParts,
        userId: nil,
        aiAgentId: nil,
        visitorId: visitorId,
        createdAt: SupportFormatters.formatISO8601(Date()),
        deletedAt: nil
      )

      let request = CreateConversationRequest(
        visitorId: visitorId,
        conversationId: localConversationId,
        defaultTimelineItems: [messageItem],
        channel: channel ?? "apple"
      )
      let response = try await conversations.create(request)

      // Hydrate timeline from the response
      timeline.hydrate(
        conversationId: response.conversation.id,
        items: response.initialTimelineItems
      )
      onMessageSent?(text)

      return response
    } catch {
      timeline.markPendingFailed(id: localId, error: error.localizedDescription)
      throw error
    }
  }

  // MARK: - ID Generation

  /// Generates a conversation ID matching the server format: "CO" + 16 alphanumeric chars.
  /// Server column is VARCHAR(18), so the ID must be at most 18 characters.
  private static let nanoidAlphabet = Array("123456789ABCDEFGHIJKLMNPQRSTUVWXYZ")
  private static func generateConversationId() -> String {
    let suffix = (0..<16).map { _ in nanoidAlphabet.randomElement() ?? "0" }
    return "CO" + String(suffix)
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

  /// Disconnects the WebSocket.
  /// Called automatically by `SupportView` when removed from the view hierarchy.
  /// Can also be called manually if the host needs to disconnect earlier.
  /// Idempotent — safe to call multiple times.
  public func disconnect() async {
    await webSocket.disconnect()
  }
}

// MARK: - Pending Identity

private struct PendingIdentity: Sendable, Equatable {
  let externalId: String?
  let email: String?
  let name: String?
  let image: String?
  let metadata: VisitorMetadata?
}

private struct MetadataFlushState {
  var pendingMetadata: VisitorMetadata?
  var metadataRevision = 0
  var flushedMetadataRevision = 0
  var activeFlushTask: Task<Void, Error>?
  var lastFlushError: Error?

  mutating func reset() {
    pendingMetadata = nil
    metadataRevision = 0
    flushedMetadataRevision = 0
    lastFlushError = nil
    activeFlushTask?.cancel()
    activeFlushTask = nil
  }

  @discardableResult
  mutating func merge(_ metadata: VisitorMetadata) -> Int {
    if var existing = pendingMetadata {
      existing.storage.merge(metadata.storage) { _, new in new }
      pendingMetadata = existing
    } else {
      pendingMetadata = metadata
    }
    metadataRevision += 1
    return metadataRevision
  }
}
