import Foundation

/// Actor-based WebSocket client with heartbeat, reconnection, and event dispatch.
actor WebSocketClient {
  private let configuration: Configuration
  private let session: URLSession
  private var task: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var heartbeatTask: Task<Void, Never>?
  private var reconnectionPolicy = ReconnectionPolicy()
  private var isIntentionalDisconnect = false
  private var visitorId: String?

  /// Called on the main actor when an event is received.
  private let onEvent: @MainActor @Sendable (WebSocketEvent) -> Void

  /// Called on the main actor when connection state changes.
  private let onConnectionChange: @MainActor @Sendable (Bool) -> Void

  private let heartbeatInterval: TimeInterval = 15
  private let heartbeatTimeout: TimeInterval = 45

  init(
    configuration: Configuration,
    session: URLSession = .shared,
    onEvent: @escaping @MainActor @Sendable (WebSocketEvent) -> Void,
    onConnectionChange: @escaping @MainActor @Sendable (Bool) -> Void
  ) {
    self.configuration = configuration
    self.session = session
    self.onEvent = onEvent
    self.onConnectionChange = onConnectionChange
  }

  // MARK: - Public API

  func connect(visitorId: String) {
    self.visitorId = visitorId
    isIntentionalDisconnect = false
    reconnectionPolicy.reset()
    establishConnection()
  }

  func disconnect() {
    isIntentionalDisconnect = true
    tearDown()
    Task { @MainActor in onConnectionChange(false) }
  }

  func send(_ text: String) async throws {
    guard let task else { throw CossistantError.notConnected }
    try await task.send(.string(text))
  }

  // MARK: - Connection Lifecycle

  private func establishConnection() {
    tearDown()

    var components = URLComponents(url: configuration.webSocketBaseURL, resolvingAgainstBaseURL: false)!
    var queryItems = [URLQueryItem(name: "publicKey", value: configuration.apiKey)]
    if let visitorId {
      queryItems.append(URLQueryItem(name: "visitorId", value: visitorId))
    }
    components.queryItems = queryItems

    let wsTask = session.webSocketTask(with: components.url!)
    wsTask.resume()
    self.task = wsTask

    receiveTask = Task { [weak self] in
      await self?.receiveLoop()
    }

    heartbeatTask = Task { [weak self] in
      await self?.heartbeatLoop()
    }

    Task { @MainActor in onConnectionChange(true) }
  }

  private func tearDown() {
    receiveTask?.cancel()
    heartbeatTask?.cancel()
    receiveTask = nil
    heartbeatTask = nil
    task?.cancel(with: .normalClosure, reason: nil)
    task = nil
  }

  // MARK: - Receive Loop

  private func receiveLoop() async {
    guard let task else { return }

    while !Task.isCancelled {
      do {
        let message = try await task.receive()
        switch message {
        case .string(let text):
          handleTextMessage(text)
        case .data(let data):
          handleDataMessage(data)
        @unknown default:
          break
        }
      } catch {
        if !Task.isCancelled && !isIntentionalDisconnect {
          Task { @MainActor in onConnectionChange(false) }
          await attemptReconnect()
        }
        return
      }
    }
  }

  private func handleTextMessage(_ text: String) {
    if text == "pong" { return }

    guard let data = text.data(using: .utf8) else { return }
    handleDataMessage(data)
  }

  private func handleDataMessage(_ data: Data) {
    guard let event = WebSocketEventParser.parse(from: data) else { return }
    reconnectionPolicy.reset()
    Task { @MainActor in onEvent(event) }
  }

  // MARK: - Heartbeat

  private func heartbeatLoop() async {
    while !Task.isCancelled {
      do {
        try await Task.sleep(for: .seconds(heartbeatInterval))
        try await task?.send(.string("ping"))
      } catch {
        if !Task.isCancelled && !isIntentionalDisconnect {
          await attemptReconnect()
        }
        return
      }
    }
  }

  // MARK: - Reconnection

  private func attemptReconnect() async {
    guard !isIntentionalDisconnect, reconnectionPolicy.shouldRetry else { return }

    let delay = reconnectionPolicy.currentDelay
    reconnectionPolicy.recordAttempt()

    do {
      try await Task.sleep(for: .seconds(delay))
    } catch {
      return
    }

    guard !isIntentionalDisconnect else { return }
    establishConnection()
  }
}
