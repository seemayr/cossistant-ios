import SwiftUI
import SFSafeSymbols

/// Main support view — bootstraps the client and provides conversation list + chat.
///
/// `SupportView` does **not** include its own `NavigationStack`.
/// It uses `.navigationTitle` and `.toolbar` modifiers that compose with
/// whatever navigation container the host provides.
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
///     metadata: VisitorMetadata([
///       "gameId": .string(game.id),
///       "groupId": .string(group.id),
///     ]),
///     initialMessage: "I'm having trouble loading a game."
///   )
/// )
/// ```
public struct SupportView: View {
  private let client: CossistantClient
  private let autoCreate: SupportContext?
  private let onDismiss: (() -> Void)?

  @State private var isBootstrapped = false
  @State private var bootError: String?
  @State private var selectedConversation: Conversation?
  @State private var isCreatingNew = false
  @State private var activeContext: SupportContext?

  /// - Parameters:
  ///   - client: The initialized CossistantClient.
  ///   - autoCreate: When provided, automatically creates a new conversation on first open
  ///                 with the given context metadata and optional initial message.
  ///   - onDismiss: When provided, a close button is shown in the toolbar.
  ///                The host is responsible for actually dismissing the view.
  public init(
    client: CossistantClient,
    autoCreate: SupportContext? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.client = client
    self.autoCreate = autoCreate
    self.onDismiss = onDismiss
  }

  public var body: some View {
    Group {
      if let bootError {
        errorView(bootError)
      } else if !isBootstrapped {
        CossLoadingOverlayView(R.string(.connecting))
      } else if isCreatingNew {
        ChatView(
          client: client,
          timeline: client.timeline,
          connection: client.connection,
          conversations: client.conversations,
          agents: client.agents,
          visitorId: client.visitorId,
          conversationId: nil,
          context: activeContext,
          onBack: navigateBack
        )
      } else if let conversation = selectedConversation {
        ChatView(
          client: client,
          timeline: client.timeline,
          connection: client.connection,
          conversations: client.conversations,
          agents: client.agents,
          visitorId: client.visitorId,
          conversationId: conversation.id,
          context: nil,
          onBack: navigateBack
        )
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
    .task {
      await bootstrap()
    }
    .onDisappear {
      Task { await client.disconnect() }
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
        selectedConversation = conversation
      },
      onNewConversation: {
        activeContext = nil
        isCreatingNew = true
      }
    )
    .navigationTitle(R.string(.support_title))
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  // MARK: - Actions

  private func bootstrap() async {
    do {
      try await client.bootstrap()
      try await client.conversations.load()
      isBootstrapped = true

      // Auto-create: skip the list and go straight to a new conversation
      if let context = autoCreate {
        activeContext = context
        isCreatingNew = true

        // Attach context metadata to visitor
        if !context.metadata.storage.isEmpty {
          try? await client.updateMetadata(context.metadata)
        }
      }
    } catch {
      bootError = error.localizedDescription
    }
  }

  private func navigateBack() {
    selectedConversation = nil
    isCreatingNew = false
    activeContext = nil
    client.timeline.clear()
    Task { try? await client.conversations.load() }
  }

  private func errorView(_ message: String) -> some View {
    ContentUnavailableView {
      Label(R.string(.error_connection), systemSymbol: .wifiExclamationmark)
    } description: {
      Text(message)
    } actions: {
      Button(action: {
        bootError = nil
        Task { await bootstrap() }
      }, label: {
        Label(R.string(.retry), systemSymbol: .arrowClockwise)
          .font(.body)
          .fontWeight(.medium)
      })
      .buttonStyle(HapticButtonStyle(haptic: .retry))
      

      if let email = client.configuration.supportEmail {
        DirectContactButton(email: email)
          .font(.body)
          .fontWeight(.medium)
      }
    }
    .transition(.fadeInScale)
  }
}

// MARK: - Live Preview

private let previewAPIKey = ProcessInfo.processInfo.environment["COSSISTANT_API_KEY"] ?? "pk_test_YOUR_KEY_HERE"
private let previewOrigin = ProcessInfo.processInfo.environment["COSSISTANT_ORIGIN"] ?? "http://localhost:3000"

#Preview("Support (Standalone)") {
  SupportNavigationView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: previewAPIKey,
        origin: previewOrigin,
        supportEmail: "support@sample.com"
      )
    )
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
    autoCreate: SupportContext(
      source: "game_loading",
      metadata: VisitorMetadata([
        "gameId": .string("test_game_001"),
        "groupId": .string("test_group_001"),
      ]),
      initialMessage: "I'm having trouble loading a game."
    )
  )
}
