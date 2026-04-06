import SwiftUI
import SFSafeSymbols

/// Main support view — bootstraps the client and provides conversation list + chat.
///
/// From settings (conversation list):
/// ```swift
/// SupportView(client: client)
/// ```
///
/// From game loading (auto-create with context):
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

  @State private var isBootstrapped = false
  @State private var bootError: String?
  @State private var selectedConversation: Conversation?
  @State private var isCreatingNew = false
  @State private var activeContext: SupportContext?

  /// - Parameters:
  ///   - client: The initialized CossistantClient.
  ///   - autoCreate: When provided, automatically creates a new conversation on first open
  ///                 with the given context metadata and optional initial message.
  public init(
    client: CossistantClient,
    autoCreate: SupportContext? = nil
  ) {
    self.client = client
    self.autoCreate = autoCreate
  }

  public var body: some View {
    NavigationStack {
      Group {
        if let bootError {
          errorView(bootError)
        } else if !isBootstrapped {
          SupportLoadingOverlayView(R.string(.connecting))
        } else if isCreatingNew {
          ChatView(
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
    }
    .navigationBarBackButtonHidden()
    .task {
      await bootstrap()
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
      Button(R.string(.retry)) {
        bootError = nil
        Task { await bootstrap() }
      }
      .buttonStyle(HapticButtonStyle(haptic: .retry))
    }
    .transition(.fadeInScale)
  }
}

// MARK: - Live Preview

#Preview("Support (Live API)") {
  SupportView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: "pk_test_584b4b6d7220ee2e1b83cbfb965bc9507347feccf2a604a3504d27d0930115db",
        origin: "http://localhost:3000"
      )
    )
  )
}

#Preview("Support Embedded") {
  VStack {
    SupportView(
      client: CossistantClient(
        configuration: Configuration(
          apiKey: "pk_test_584b4b6d7220ee2e1b83cbfb965bc9507347feccf2a604a3504d27d0930115db",
          origin: "http://localhost:3000"
        )
      )
    )
    .clipShape(.rect(cornerRadius: 32))
    .padding(16)
  }
  .background(Color.purple)
  
}

#Preview("Support (Auto-Create)") {
  SupportView(
    client: CossistantClient(
      configuration: Configuration(
        apiKey: "pk_test_584b4b6d7220ee2e1b83cbfb965bc9507347feccf2a604a3504d27d0930115db",
        origin: "http://localhost:3000"
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
