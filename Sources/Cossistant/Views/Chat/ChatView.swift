import SwiftUI
import SFSafeSymbols

/// Chat lifecycle state — drives loading, ready, and error UI.
enum ChatState: Equatable {
  case creating
  case loading
  case ready
  case failed(String)

  static func == (lhs: ChatState, rhs: ChatState) -> Bool {
    switch (lhs, rhs) {
    case (.creating, .creating), (.loading, .loading), (.ready, .ready): return true
    case (.failed(let a), .failed(let b)): return a == b
    default: return false
    }
  }
}

/// Chat view — handles both existing conversations and creating new ones.
/// When `conversationId` is nil, instantly shows the chat UI while creating
/// the conversation in the background. Input is disabled until ready.
public struct ChatView: View {
  private let timeline: TimelineStore
  private let connection: ConnectionStore
  private let conversations: ConversationStore
  private let agents: AgentRegistry
  private let visitorId: String?
  private let initialConversationId: String?
  private let context: SupportContext?
  private let onBack: (() -> Void)?

  @State private var chatState: ChatState = .loading
  @State private var activeConversationId: String?
  @State private var inputText = ""
  @State private var isSending = false

  private var activeConversation: Conversation? {
    guard let id = activeConversationId else { return nil }
    return conversations.conversation(byId: id)
  }

  /// Whether the active conversation is closed (resolved, spam, or archived).
  private var isConversationClosed: Bool {
    activeConversation?.isClosed ?? false
  }

  private var activeConversationStatus: ConversationStatus? {
    activeConversation?.status
  }

  private var activeConversationDeletedAt: String? {
    activeConversation?.deletedAt
  }

  private var activeConversationRating: Int? {
    activeConversation?.visitorRating
  }

  public init(
    timeline: TimelineStore,
    connection: ConnectionStore,
    conversations: ConversationStore,
    agents: AgentRegistry,
    visitorId: String?,
    conversationId: String?,
    context: SupportContext? = nil,
    onBack: (() -> Void)? = nil
  ) {
    self.timeline = timeline
    self.connection = connection
    self.conversations = conversations
    self.agents = agents
    self.visitorId = visitorId
    self.initialConversationId = conversationId
    self.context = context
    self.onBack = onBack
  }

  public var body: some View {
    VStack(spacing: 0) {
      messageArea
      Divider()
      if activeConversationStatus == .resolved && activeConversationDeletedAt == nil {
        ConversationRatingView(
          existingRating: activeConversationRating,
          onSubmit: { rating, comment in
            try? await timeline.submitRating(rating, comment: comment)
          }
        )
      } else if isConversationClosed {
        conversationClosedBar
      } else {
        inputBar
      }
    }
    .navigationTitle(R.string(.conversation_title))
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      if let onBack {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: onBack) {
            Label(R.string(.back), systemSymbol: .chevronLeft)
              .labelStyle(.iconOnly)
          }
        }
      }
    }
    .task {
      await setup()
    }
  }

  // MARK: - Message Area

  private var messageArea: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 8) {
          // Status banner for creating/loading/error
          statusBanner

          if chatState == .ready && timeline.visibleItems.isEmpty
            && timeline.pendingMessages.isEmpty {
            chatEmptyState
          }

          if timeline.hasMore {
            Button(R.string(.load_older)) {
              Task { try? await timeline.loadMore() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .buttonStyle(HapticButtonStyle())
          }

          ForEach(Array(timeline.visibleItems.enumerated()), id: \.element.id) { index, item in
            let isGrouped = isGroupedWithPrevious(index: index)
            MessageBubbleView(
              item: item,
              visitorId: visitorId,
              agents: agents,
              isGrouped: isGrouped
            )
            .id(item.id)
            .padding(.top, isGrouped ? -4 : 0)
            .transition(.slideUpFade)
          }

          ForEach(timeline.pendingMessages) { pending in
            PendingBubbleView(
              message: pending,
              onRetry: { Task { try? await timeline.retrySend(pendingId: pending.id, visitorId: visitorId) } },
              onDiscard: { timeline.discardPending(pendingId: pending.id) }
            )
            .id(pending.id)
            .transition(.slideUpFade)
          }

          // Typing indicator
          if let convId = activeConversationId, connection.isAgentTyping(in: convId) {
            TypingBubbleView(
              name: connection.typingAgentName(for: convId),
              image: connection.typingIndicators[convId]?.image
            )
            .transition(.fadeInScale)
          }

          // AI processing (hide if the last visible item is already a tool — avoids duplicate indicator)
          if let convId = activeConversationId, connection.isAIProcessing(in: convId),
             timeline.visibleItems.last?.type != .tool {
            AIProgressBubbleView(
              phase: connection.aiProcessing[convId]?.phase,
              message: connection.aiStatusMessage(for: convId)
            )
            .transition(.fadeInScale)
          }

          // Read receipts
          if let convId = activeConversationId {
            let receipts = connection.seen(for: convId)
            if !receipts.isEmpty {
              SeenIndicatorView(receipts: receipts)
                .padding(.top, -4)
                .transition(.opacity)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
      .onChange(of: timeline.visibleItems.count) { oldCount, newCount in
        scrollToBottom(proxy: proxy)
        // Play haptic for agent messages arriving
        if newCount > oldCount, let last = timeline.visibleItems.last,
          last.visitorId == nil {
          SupportHaptics.play(.messageReceived)
        }
      }
      .onChange(of: timeline.pendingMessages.count) {
        scrollToBottom(proxy: proxy)
      }
    }
  }

  // MARK: - Status Banner

  @ViewBuilder
  private var statusBanner: some View {
    switch chatState {
    case .creating:
      SupportLoadingView(R.string(.creating_conversation))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .transition(.fadeInScale)

    case .loading:
      SupportLoadingView(R.string(.loading_messages))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .transition(.fadeInScale)

    case .failed(let message):
      VStack(spacing: 12) {
        Label(R.string(.error_title), systemSymbol: .exclamationmarkTriangle)
          .font(.subheadline)
          .foregroundStyle(.red)
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button(R.string(.retry)) {
          Task { await setup() }
        }
        .buttonStyle(HapticButtonStyle(haptic: .retry))
        .controlSize(.small)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
      .transition(.fadeInScale)

    case .ready:
      EmptyView()
    }
  }

  // MARK: - Chat Empty State

  private var chatEmptyState: some View {
    VStack(spacing: 16) {
      Image(systemSymbol: .bubbleLeftAndBubbleRightFill)
        .font(.system(size: 48))
        .foregroundStyle(.secondary.opacity(0.3))
        .symbolEffect(.pulse, options: .repeating.speed(0.5))

      Text(R.string(.empty_chat_title))
        .font(.headline)
        .foregroundStyle(.secondary)

      Text(R.string(.empty_chat_description))
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 60)
    .padding(.horizontal, 32)
    .transition(.fadeInScale)
  }

  // MARK: - Conversation Closed Bar

  private var conversationClosedBar: some View {
    VStack(spacing: 8) {
      Image(systemSymbol: .checkmarkCircleFill)
        .font(.title3)
        .foregroundStyle(.green)
      Text(R.string(.conversation_closed))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(.regularMaterial)
  }

  // MARK: - Input Bar

  private var inputBar: some View {
    HStack(spacing: 12) {
      TextField(R.string(.input_placeholder), text: $inputText, axis: .vertical)
        .textFieldStyle(.plain)
        .lineLimit(1...5)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.12))
        .clipShape(.rect(cornerRadius: 20))
        .disabled(!isReady)

      Button(action: sendMessage) {
        Image(systemSymbol: .arrowUpCircleFill)
          .font(.system(size: 32))
          .foregroundStyle(canSend ? Color.accentColor : Color.secondary.opacity(0.4))
      }
      .buttonStyle(HapticButtonStyle(haptic: .messageSent))
      .disabled(!canSend)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .opacity(isReady ? 1 : 0.5)
    .animation(CossistantAnimation.quick, value: isReady)
  }

  // MARK: - State

  private var isReady: Bool { chatState == .ready }

  private var canSend: Bool {
    isReady && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
  }

  // MARK: - Message Grouping

  /// Five-minute threshold for grouping consecutive messages from the same sender.
  private static let groupingInterval: TimeInterval = 300

  private func isGroupedWithPrevious(index: Int) -> Bool {
    let items = timeline.visibleItems
    guard index > 0 else { return false }
    let current = items[index]
    guard current.type == .message else { return false }

    // Find the previous message, skipping events/tools in between
    guard let previous = items[..<index].last(where: { $0.type == .message }) else { return false }

    // Same sender?
    guard sameSender(current, previous) else { return false }

    // Within time threshold?
    let formatter = ISO8601DateFormatter()
    guard let currentDate = formatter.date(from: current.createdAt),
      let previousDate = formatter.date(from: previous.createdAt) else { return false }
    return currentDate.timeIntervalSince(previousDate) < Self.groupingInterval
  }

  private func sameSender(_ a: TimelineItem, _ b: TimelineItem) -> Bool {
    if let av = a.visitorId, let bv = b.visitorId, av == bv { return true }
    if let au = a.userId, let bu = b.userId, au == bu { return true }
    if let aa = a.aiAgentId, let ba = b.aiAgentId, aa == ba { return true }
    return false
  }

  // MARK: - Actions

  private func setup() async {
    if let conversationId = initialConversationId {
      // Existing conversation — load messages
      chatState = .loading
      activeConversationId = conversationId
      do {
        try await timeline.load(conversationId: conversationId)
        // Only mark seen if conversation is still open (archived returns 404)
        if !isConversationClosed {
          try? await timeline.markSeen()
        }
        chatState = .ready
      } catch {
        SupportHaptics.play(.error)
        chatState = .failed(error.localizedDescription)
      }
    } else {
      // New conversation — create it
      chatState = .creating
      do {
        let request = CreateConversationRequest(visitorId: visitorId, channel: "mobile")
        let response: CreateConversationResponse = try await timeline.rest.request(.createConversation, body: request)
        activeConversationId = response.conversation.id
        try await timeline.load(conversationId: response.conversation.id)
        SupportHaptics.play(.conversationCreated)
        chatState = .ready

        // Auto-send initial message from context
        if let message = context?.initialMessage, !message.isEmpty {
          try? await timeline.sendMessage(text: message, visitorId: visitorId)
        }
      } catch {
        SupportHaptics.play(.error)
        chatState = .failed(error.localizedDescription)
      }
    }
  }

  private func sendMessage() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, isReady else { return }
    inputText = ""
    isSending = true
    SupportHaptics.play(.messageSent)
    Task {
      try? await timeline.sendMessage(text: text, visitorId: visitorId)
      isSending = false
    }
  }

  private func scrollToBottom(proxy: ScrollViewProxy) {
    let lastId = timeline.pendingMessages.last?.id ?? timeline.visibleItems.last?.id
    guard let lastId else { return }
    withCossistantAnimation(.easeOut(duration: 0.2)) {
      proxy.scrollTo(lastId, anchor: .bottom)
    }
  }
}

// MARK: - Typing Bubble (bouncing dots)

private struct TypingBubbleView: View {
  let name: String?
  let image: String?
  @State private var isAnimating = false

  var body: some View {
    HStack(spacing: 8) {
      if let image, let url = URL(string: image) {
        AsyncImage(url: url) { img in img.resizable() } placeholder: {
          Circle().fill(.secondary.opacity(0.3))
        }
        .frame(width: 24, height: 24)
        .clipShape(.circle)
      }

      VStack(alignment: .leading, spacing: 6) {
        if let name {
          Text(R.string(.typing_indicator, name))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        HStack(spacing: 4) {
          ForEach(0..<3, id: \.self) { index in
            Circle()
              .fill(.tint)
              .frame(width: 6, height: 6)
              .offset(y: isAnimating ? -4 : 0)
              .animation(
                .easeInOut(duration: 0.4)
                  .repeatForever(autoreverses: true)
                  .delay(Double(index) * 0.15),
                value: isAnimating
              )
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.12))
        .clipShape(.rect(cornerRadius: 16))
      }
      Spacer()
    }
    .onAppear { isAnimating = true }
    .onDisappear { isAnimating = false }
  }
}

// MARK: - AI Progress Bubble (themed spinner with phase labels)

private struct AIProgressBubbleView: View {
  let phase: String?
  let message: String?
  @State private var isAnimating = false

  private var isDone: Bool { phase == "done" }

  var body: some View {
    HStack {
      HStack(spacing: 8) {
        if isDone {
          Image(systemSymbol: .checkmarkCircleFill)
            .font(.caption)
            .foregroundStyle(.green)
        } else {
          // Themed dot spinner
          HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
              Circle()
                .fill(.tint)
                .frame(width: 5, height: 5)
                .scaleEffect(isAnimating ? 1.2 : 0.6)
                .opacity(isAnimating ? 1 : 0.3)
                .animation(
                  .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2),
                  value: isAnimating
                )
            }
          }
        }

        Text(phaseLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(isDone ? Color.green.opacity(0.08) : Color.accentColor.opacity(0.08))
      .clipShape(.rect(cornerRadius: 16))
      Spacer()
    }
    .onAppear { isAnimating = true }
    .onDisappear { isAnimating = false }
    .animation(.snappy(duration: 0.2), value: isDone)
  }

  private var phaseLabel: String {
    if isDone { return R.string(.reply_sent) }
    if let message, !message.isEmpty { return message }
    switch phase {
    case "thinking": return R.string(.ai_phase_thinking)
    case "searching": return R.string(.ai_phase_searching)
    case "generating": return R.string(.ai_phase_generating)
    default: return R.string(.ai_phase_default)
    }
  }
}

// MARK: - Seen Indicator

private struct SeenIndicatorView: View {
  let receipts: [SeenReceipt]

  var body: some View {
    HStack {
      Spacer()
      HStack(spacing: -4) {
        ForEach(receipts.prefix(3)) { receipt in
          seenAvatar(name: receipt.name, image: receipt.image)
            .overlay(Circle().stroke(.background, lineWidth: 1.5))
        }
        if receipts.count > 3 {
          Text("+\(receipts.count - 3)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      Text(R.string(.seen))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func seenAvatar(name: String?, image: String?) -> some View {
    let info = AgentInfo(
      id: "",
      name: name ?? "?",
      image: image,
      kind: .human,
      onlineStatus: .offline
    )
    return AgentAvatarView(info: info, size: 18)
  }
}
