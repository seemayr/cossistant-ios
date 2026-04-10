import SwiftUI
import SFSafeSymbols

/// Main support view — bootstraps the client and provides conversation list + chat.
///
/// `SupportView` does **not** include its own `NavigationStack`.
/// It uses `.navigationTitle` and `.toolbar` modifiers that compose with
/// whatever navigation container the host provides.
///
/// The connection is bootstrapped when the view appears and automatically
/// disconnected when the view is removed from the hierarchy.
///
/// **Pushed into an existing NavigationStack:**
/// ```swift
/// SupportView(client: client)
/// ```
///
/// **In a sheet / fullscreen cover (use the NavigationStack wrapper):**
/// ```swift
/// SupportNavigationView(client: client, onDismiss: { dismiss() })
/// ```
///
/// **Auto-create with context:**
/// ```swift
/// SupportView(
///   client: client,
///   autoCreate: SupportContext(
///     source: "game_loading",
///     autoCreateConversation: true,
///     conversationContext: VisitorMetadata([
///       "gameId": .string(game.id),
///       "groupId": .string(group.id),
///     ]),
///     initialMessage: "I’m having trouble loading a game."
///   )
/// )
/// ```
public struct SupportView: View {
  private let client: CossistantClient
  private let supportContext: SupportContext?
  private let conversationChannel: String?
  private let onDismiss: (() -> Void)?

  @State private var connectionToken = ConnectionToken()
  @State private var supportSession: SupportSessionStore
  @State private var isBootstrapped = false
  @State private var bootError: String?
  @State private var chatDestination: ChatDestination?

  /// - Parameters:
  ///   - client: The initialized CossistantClient.
  ///   - channel: Optional conversation channel forwarded when this view creates
  ///              a new conversation. Defaults to the client's built-in channel.
  ///   - autoCreate: When provided, automatically creates a new conversation on first open
  ///                 with the given context metadata and optional initial message.
  ///   - onDismiss: When provided, a close button is shown in the toolbar.
  ///                The host is responsible for actually dismissing the view.
  public init(
    client: CossistantClient,
    channel: String? = nil,
    autoCreate: SupportContext? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.client = client
    self.conversationChannel = channel
    self.supportContext = autoCreate
    self.onDismiss = onDismiss
    _supportSession = State(initialValue: SupportSessionStore(context: autoCreate))
  }

  public var body: some View {
    Group {
      if let bootError {
        errorView(bootError)
      } else if !isBootstrapped {
        CossLoadingOverlayView(R.string(.connecting))
      } else {
        conversationList
      }
    }
    .background(.background)
    .toolbar {
      if let onDismiss {
        ToolbarItem(placement: .confirmationAction) {
          Button(action: onDismiss) {
            Label(R.string(.close), systemSymbol: .xmark)
              .labelStyle(.iconOnly)
          }
          .buttonStyle(HapticButtonStyle(haptic: .buttonTap))
        }
      }
    }
    .navigationDestination(item: $chatDestination) { destination in
      ChatView(
        client: client,
        timeline: client.timeline,
        connection: client.connection,
        conversations: client.conversations,
        agents: client.agents,
        visitorId: client.visitorId,
        conversationId: destination.conversationId,
        context: destination.context,
        conversationChannel: conversationChannel,
        supportSession: supportSession
      )
    }
    .onChange(of: chatDestination) { oldValue, newValue in
      if oldValue != nil, newValue == nil {
        // User navigated back from chat — clean up and refresh
        client.timeline.clear()
        Task { try? await client.conversations.load() }
      }
    }
    .task {
      await connect()
    }
  }

  // MARK: - Conversation List

  private var conversationList: some View {
    ConversationListView(
      conversations: client.conversations,
      agents: client.agents,
      connection: client.connection,
      timeline: client.timeline,
      visitorId: client.visitorId,
      onSelect: { conversation in
        SupportHaptics.play(.conversationOpened)
        chatDestination = .conversation(id: conversation.id)
      },
      onNewConversation: {
        chatDestination = .new(context: supportContext)
      }
    )
    .safeAreaInset(edge: .top) {
      if let issue = supportSession.bannerIssue {
        SupportPreparationBanner(
          issue: issue,
          isRetrying: supportSession.isPreparing,
          onRetry: {
            Task {
              await supportSession.retry(using: client)
              withCossistantAnimation { }
            }
          },
          onDismiss: {
            withCossistantAnimation {
              supportSession.dismiss(issue)
            }
          }
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .navigationTitle(R.string(.support_title))
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  // MARK: - Actions

  private func connect() async {
    guard !isBootstrapped else { return }
    do {
      try await connectionToken.attach(client)
      try await client.conversations.load()
      isBootstrapped = true
      supportSession.prepareOnOpen(using: client)

      // Auto-create: skip the list and go straight to a new conversation
      if let context = supportContext, context.autoCreateConversation {
        chatDestination = .new(context: context)
      }
    } catch {
      bootError = error.localizedDescription
    }
  }

  private func errorView(_ message: String) -> some View {
    ContentUnavailableView {
      Label(R.string(.error_connection), systemSymbol: .wifiExclamationmark)
    } description: {
      Text(message)
    } actions: {
      Button(action: {
        bootError = nil
        Task { await connect() }
      }, label: {
        Label(R.string(.retry), systemSymbol: .arrowClockwise)
          .font(.body)
          .fontWeight(.medium)
      })
      .buttonStyle(HapticButtonStyle(haptic: .retry))

      if let email = client.supportEmail {
        DirectContactButton(email: email)
          .font(.body)
          .fontWeight(.medium)
      }
    }
    .transition(.fadeInScale)
  }
}

// MARK: - Connection Token

/// Ties the client connection lifetime to the view's presence in the hierarchy.
///
/// `@State` is preserved across NavigationStack push/pop but deallocated when
/// the view is truly removed from the graph. On deallocation, `deinit` fires
/// a best-effort disconnect. The server's heartbeat timeout (45s) handles
/// edge cases where the Task never executes (e.g., app termination).
private final class ConnectionToken: @unchecked Sendable {
  // Safety: written once from MainActor (.task), read once from deinit (after
  // all access ends). SwiftUI's lifecycle guarantees write-before-read ordering.
  nonisolated(unsafe) private var client: CossistantClient?

  /// Bootstraps the client and stores the reference for lifecycle management.
  /// Idempotent — safe to call on `.task` re-invocation (e.g., nav back).
  @MainActor
  func attach(_ client: CossistantClient) async throws {
    guard self.client == nil else { return }
    try await client.bootstrap()
    self.client = client
  }

  deinit {
    guard let client else { return }
    Task { @MainActor in await client.disconnect() }
  }
}

// MARK: - Chat Destination

/// Navigation destination for chat — either an existing conversation or a new one.
public enum ChatDestination: Hashable {
  case conversation(id: String)
  case new(context: SupportContext?)

  var conversationId: String? {
    switch self {
    case .conversation(let id): id
    case .new: nil
    }
  }

  var context: SupportContext? {
    switch self {
    case .conversation: nil
    case .new(let context): context
    }
  }
}

// MARK: - Live Preview

private let previewAPIKey = ProcessInfo.processInfo.environment["COSSISTANT_API_KEY"] ?? "pk_test_YOUR_KEY_HERE"
private let previewOrigin = ProcessInfo.processInfo.environment["COSSISTANT_ORIGIN"] ?? "http://localhost:3000"
private let previewExternalID = ProcessInfo.processInfo.environment["COSSISTANT_PREVIEW_EXTERNAL_ID"] ?? "ios-ID"
private let previewEmail = ProcessInfo.processInfo.environment["COSSISTANT_PREVIEW_EMAIL"] ?? "ios@sdk.com"
private let previewName = ProcessInfo.processInfo.environment["COSSISTANT_PREVIEW_NAME"] ?? "iOS Preview"

private var previewIdentity: SupportIdentity? {
  let identity = SupportIdentity(
    externalId: previewExternalID,
    email: previewEmail,
    name: previewName
  )
  return identity.isEmpty ? nil : identity
}

#Preview("Support (Standalone)") {
  SupportNavigationView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: previewAPIKey,
        origin: previewOrigin,
        supportEmail: "support@sample.com"
      )
    ),
    channel: "ios_preview"
  )
}

#Preview("Support (In NavigationStack)") {
  NavigationStack {
    SupportView(
      client: CossistantClient(
        configuration: Configuration(
          apiKey: previewAPIKey,
          origin: previewOrigin
        )
      )
    )
  }
}

#Preview("Support (Embedded)") {
  VStack {
    SupportNavigationView(
      client: CossistantClient(
        configuration: Configuration(
          apiKey: previewAPIKey,
          origin: previewOrigin,
          supportEmail: "support@sample.com"
        )
      )
    )
    .cossistantDesign(CossistantDesign(accentColor: .purple, fontDesign: .rounded))
    .clipShape(.rect(cornerRadius: 16))
  }
  .padding(32)
  .background(.purple)
}

#Preview("Support (Sheet with Dismiss)") {
  SupportNavigationView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: previewAPIKey,
        origin: previewOrigin,
        supportEmail: "support@sample.com"
      )
    ),
    channel: "ios_sheet_preview",
    onDismiss: {}
  )
}

#Preview("Support (Auto-Create)") {
  SupportNavigationView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: previewAPIKey,
        origin: previewOrigin
      )
    ),
    channel: "ios_autocreate_preview",
    autoCreate: SupportContext(
      source: "game_loading",
      autoCreateConversation: true,
      identity: previewIdentity,
      conversationContext: VisitorMetadata([
        "gameId": .string("test_game_001"),
        "groupId": .string("test_group_001"),
      ]),
      initialMessage: "I'm having trouble loading a game."
    )
  )
}

#Preview("Support (Identify)") {
  SupportNavigationView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: previewAPIKey,
        origin: previewOrigin
      )
    ),
    channel: "ios_identify_preview",
    autoCreate: SupportContext(
      source: "preview_identify",
      autoCreateConversation: true,
      identity: previewIdentity,
      initialMessage: "Testing identify from preview."
    )
  )
}
