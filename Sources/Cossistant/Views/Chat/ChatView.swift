import SwiftUI
import SFSafeSymbols

/// Chat lifecycle state — drives loading, ready, and error UI.
enum ChatState: Equatable {
  case creating
  case loading
  case ready
  case failed(String)
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
        LazyVStack(spacing: 0) {
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
            .padding(.top, 16)
            .buttonStyle(HapticButtonStyle())
          }

          ForEach(groupedItems, id: \.item.id) { entry in
            MessageBubbleView(
              item: entry.item,
              visitorId: visitorId,
              agents: agents,
              isGrouped: entry.isGrouped
            )
            .id(entry.item.id)
            .padding(.top, entry.isGrouped ? 4 : 12)
            .transition(.slideUpFade)
          }

          ForEach(timeline.pendingMessages) { pending in
            PendingBubbleView(
              message: pending,
              onRetry: { Task { try? await timeline.retrySend(pendingId: pending.id, visitorId: visitorId) } },
              onDiscard: { timeline.discardPending(pendingId: pending.id) }
            )
            .id(pending.id)
            .padding(.top, 8)
            .transition(.slideUpFade)
          }

          // Typing indicator
          if let convId = activeConversationId, connection.isAgentTyping(in: convId) {
            TypingBubbleView(
              name: connection.typingAgentName(for: convId),
              image: connection.typingIndicators[convId]?.image
            )
            .padding(.top, 8)
            .transition(.fadeInScale)
          }

          // AI processing (hide if the last visible item is already a tool — avoids duplicate indicator)
          if let convId = activeConversationId, connection.isAIProcessing(in: convId),
             timeline.visibleItems.last?.type != .tool {
            AIProgressBubbleView(
              phase: connection.aiProcessing[convId]?.phase,
              message: connection.aiStatusMessage(for: convId)
            )
            .padding(.top, 8)
            .transition(.fadeInScale)
          }

          // Read receipts
          if let convId = activeConversationId {
            let receipts = connection.seen(for: convId)
            if !receipts.isEmpty {
              SeenIndicatorView(receipts: receipts)
                .padding(.top, 4)
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
    VStack(spacing: 20) {
      ChatEmptyIllustration()

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
    HStack(spacing: 6) {
      Image(systemSymbol: .checkmarkCircleFill)
        .font(.title3)
        .foregroundStyle(.green)
      Text(R.string(.conversation_closed))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 24)
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity)
    
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
        Label(R.string(.send), systemSymbol: .arrowUpCircleFill)
          .labelStyle(.iconOnly)
          .font(.title)
          .foregroundStyle(canSend ? Color.accentColor : .secondary.opacity(0.4))
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

  private var groupedItems: [(item: TimelineItem, isGrouped: Bool)] {
    timeline.visibleItems.enumerated().map { index, item in
      (item: item, isGrouped: isGroupedWithPrevious(index: index))
    }
  }

  /// Five-minute threshold for grouping consecutive messages from the same sender.
  private static let groupingInterval: TimeInterval = 300

  private func isGroupedWithPrevious(index: Int) -> Bool {
    let items = timeline.visibleItems
    guard index > 0 else {
      logGrouping(index: index, result: false, reason: "first item")
      return false
    }
    let current = items[index]
    guard current.type == .message else {
      logGrouping(index: index, result: false, reason: "type=\(current.type) (not message)")
      return false
    }

    // Find the previous message, skipping events/tools in between
    guard let previous = items[..<index].last(where: { $0.type == .message }) else {
      logGrouping(index: index, result: false, reason: "no previous message found")
      return false
    }

    // Same sender?
    guard sameSender(current, previous) else {
      logGrouping(index: index, result: false, reason: "different sender — current: \(senderDescription(current)), previous: \(senderDescription(previous))")
      return false
    }

    // Within time threshold?
    guard let currentDate = SupportFormatters.parseISO8601( current.createdAt),
      let previousDate = SupportFormatters.parseISO8601( previous.createdAt) else {
      logGrouping(index: index, result: false, reason: "date parse failed — current: \"\(current.createdAt)\", previous: \"\(previous.createdAt)\"")
      return false
    }
    let delta = currentDate.timeIntervalSince(previousDate)
    let withinThreshold = delta < Self.groupingInterval
    logGrouping(index: index, result: withinThreshold, reason: withinThreshold
      ? "same sender, \(Int(delta))s apart (< \(Int(Self.groupingInterval))s)"
      : "same sender but \(Int(delta))s apart (>= \(Int(Self.groupingInterval))s threshold)")
    return withinThreshold
  }

  private func sameSender(_ a: TimelineItem, _ b: TimelineItem) -> Bool {
    if let av = a.visitorId, let bv = b.visitorId, av == bv { return true }
    if let au = a.userId, let bu = b.userId, au == bu { return true }
    if let aa = a.aiAgentId, let ba = b.aiAgentId, aa == ba { return true }
    return false
  }

  // MARK: - Grouping Debug

  private func senderDescription(_ item: TimelineItem) -> String {
    var parts: [String] = []
    if let v = item.visitorId { parts.append("visitor=\(v)") }
    if let u = item.userId { parts.append("user=\(u)") }
    if let a = item.aiAgentId { parts.append("ai=\(a)") }
    if parts.isEmpty { parts.append("no sender IDs") }
    return "[\(parts.joined(separator: ", "))]"
  }

  private func logGrouping(index: Int, result: Bool, reason: String) {
    let items = timeline.visibleItems
    let item = items[index]
    let text = (item.text ?? "").prefix(30)
    print("[Grouping] #\(index) id=\(item.id ?? "nil") type=\(item.type) \"\(text)\" → \(result ? "GROUPED" : "NOT grouped") — \(reason)")
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

// MARK: - Chat Empty Illustration

/// Staggered mini-bubbles that float in and gently bob, giving the empty state personality.
private struct ChatEmptyIllustration: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  @State private var floating = false

  private let bubbles: [(text: String, isRight: Bool, delay: Double, drift: CGFloat, rotation: Double, scale: CGFloat)] = [
    ("👋", false, 0.0, -3.5, -2.5, 1.04),
    ("💬", true, 0.15, 4.5, 3, 1.06),
    ("✨", false, 0.3, -3, -2, 1.03),
  ]

  var body: some View {
    VStack(spacing: -10) {
      ForEach(Array(bubbles.enumerated()), id: \.offset) { index, bubble in
        HStack {
          if bubble.isRight { Spacer() }
          Text(bubble.text)
            .font(.largeTitle)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.secondary.opacity(bubble.isRight ? 0.08 : 0.05))
            .clipShape(.rect(cornerRadius: 18))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .offset(y: floating ? bubble.drift : 0)
            .rotationEffect(.degrees(floating ? bubble.rotation : 0))
            .scaleEffect(floating ? bubble.scale : 1)
            .animation(
              reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7).delay(bubble.delay),
              value: appeared
            )
            .animation(
              reduceMotion ? nil : .easeInOut(duration: 2.0 + Double(index) * 0.4)
                .repeatForever(autoreverses: true)
                .delay(bubble.delay + 0.6),
              value: floating
            )
          if !bubble.isRight { Spacer() }
        }
      }
    }
    .frame(width: 170)
    .task {
      appeared = true
      try? await Task.sleep(for: .milliseconds(600))
      floating = true
    }
  }
}

// MARK: - Typing Bubble (bouncing dots)

private struct TypingBubbleView: View {
  let name: String?
  let image: String?

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
        
        AnimatedDotsView(style: .bounce)
          .padding(.horizontal, 14)
          .padding(.vertical, 14)
          .background(.secondary.opacity(0.12))
          .clipShape(.rect(cornerRadius: 16))
      }
      Spacer()
    }
  }
}

// MARK: - AI Progress Bubble (themed spinner with phase labels)

private struct AIProgressBubbleView: View {
  let phase: String?
  let message: String?

  private var isDone: Bool { phase == "done" }

  var body: some View {
    HStack {
      HStack(spacing: 8) {
        if isDone {
          Image(systemSymbol: .checkmarkCircleFill)
            .font(.caption)
            .foregroundStyle(.green)
        } else {
          AnimatedDotsView(style: .pulse, dotSize: 5, spacing: 3)
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
