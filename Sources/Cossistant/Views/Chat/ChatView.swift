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
  private let client: CossistantClient
  private let timeline: TimelineStore
  private let connection: ConnectionStore
  private let conversations: ConversationStore
  private let agents: AgentRegistry
  private let visitorId: String?
  private let initialConversationId: String?
  private let context: SupportContext?

  @State private var chatState: ChatState = .loading
  @State private var activeConversationId: String?
  @State private var inputText = ""
  @State private var isSending = false
  @State private var attachments: [FileAttachment] = []
  @State private var attachmentError: AttachmentValidationError?
  @State private var itemGroups: [ChatItemGroup] = []
  @State private var isNearBottom = true
  @Environment(\.cossistantDesign) private var design
  @FocusState private var isInputFocused: Bool

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
    client: CossistantClient,
    timeline: TimelineStore,
    connection: ConnectionStore,
    conversations: ConversationStore,
    agents: AgentRegistry,
    visitorId: String?,
    conversationId: String?,
    context: SupportContext? = nil
  ) {
    self.client = client
    self.timeline = timeline
    self.connection = connection
    self.conversations = conversations
    self.agents = agents
    self.visitorId = visitorId
    self.initialConversationId = conversationId
    self.context = context
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
    .task {
      await setup()
    }
    .onChange(of: timeline.visibleItems) {
      rebuildItemGroups()
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

          ForEach(Array(itemGroups.enumerated()), id: \.element.id) { _, group in
            ItemGroupView(
              group: group,
              visitorId: visitorId,
              agents: agents
            )
            .padding(.top, 12)
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
            let receipts = connection.seen(for: convId).filter { $0.actorType != .visitor }
            if !receipts.isEmpty {
              SeenIndicatorView(receipts: receipts)
                .padding(.top, 4)
                .transition(.opacity)
            }
          }

          // Human-note hint — visible until a human agent participates or conversation closes
          if chatState == .ready,
             !timeline.visibleItems.isEmpty,
             !isConversationClosed,
             !timeline.visibleItems.contains(where: { $0.userId != nil && $0.aiAgentId == nil }) {
            Text(R.string(.empty_chat_human_note))
              .font(.subheadline)
              .foregroundStyle(.tertiary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(.horizontal, 32)
              .padding(.top, 24)
          }

          // Bottom breathing room + scroll anchor
          Color.clear
            .frame(height: 40)
            .id("chat-bottom-anchor")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
      .scrollDismissesKeyboard(.interactively)
      .modifier(ScrollDownIndicatorModifier(
        isNearBottom: $isNearBottom,
        onScrollDown: { scrollToBottom(proxy: proxy) }
      ))
      .onChange(of: chatState) {
        guard chatState == .ready else { return }
        scrollToBottom(proxy: proxy)
      }
      .onChange(of: timeline.visibleItems.count) { oldCount, newCount in
        if isNearBottom { scrollToBottom(proxy: proxy) }
        // Play haptic for agent messages arriving
        if newCount > oldCount, let last = timeline.visibleItems.last,
          last.visitorId == nil {
          SupportHaptics.play(.messageReceived)
        }
      }
      .onChange(of: timeline.pendingMessages.count) {
        if isNearBottom { scrollToBottom(proxy: proxy) }
      }
    }
  }

  // MARK: - Status Banner

  @ViewBuilder
  private var statusBanner: some View {
    switch chatState {
    case .creating:
      CossLoadingView(R.string(.creating_conversation))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .transition(.fadeInScale)

    case .loading:
      SupportLoadingView(R.string(.loading_messages))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
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
    VStack(spacing: 6) {
      
      ChatEmptyIllustration()
        .padding(.bottom, 24)
      
      Text(R.string(.empty_chat_title))
        .font(.headline)
        .foregroundStyle(.primary)
      
      Text(R.string(.empty_chat_description))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      
      Text(R.string(.empty_chat_human_note))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.top, 32)
    }
    .multilineTextAlignment(.center)
    .padding(.top, 54)
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
    VStack(spacing: 0) {
      if !attachments.isEmpty {
        AttachmentPreviewStrip(attachments: attachments) { id in
          attachments.removeAll { $0.id == id }
        }
        Divider()
      }

      HStack(spacing: 12) {
        AttachmentPickerView(
          attachments: $attachments,
          validationError: $attachmentError,
          onPickerWillPresent: { isInputFocused = false }
        )

        TextField(R.string(.input_placeholder), text: $inputText, axis: .vertical)
          .focused($isInputFocused)
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
            .foregroundStyle(canSend ? design.accentColor : .secondary.opacity(0.4))
        }
        .buttonStyle(HapticButtonStyle(haptic: .messageSent))
        .disabled(!canSend)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .opacity(isReady ? 1 : 0.5)
    .animation(CossistantAnimation.quick, value: isReady)
    .alert(
      R.string(.error_title),
      isPresented: Binding(
        get: { attachmentError != nil },
        set: { if !$0 { attachmentError = nil } }
      )
    ) {
      Button("OK") { attachmentError = nil }
    } message: {
      if let error = attachmentError {
        Text(error.localizedDescription)
      }
    }
  }

  // MARK: - State

  private var isReady: Bool { chatState == .ready }

  private var canSend: Bool {
    let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    return isReady && (hasText || !attachments.isEmpty) && !isSending
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
          conversations.markVisitorSeen(conversationId: conversationId)
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
    guard isReady, !text.isEmpty || !attachments.isEmpty else { return }

    let filesToSend = attachments
    inputText = ""
    attachments = []
    isSending = true
    SupportHaptics.play(.messageSent)

    Task {
      if filesToSend.isEmpty {
        try? await timeline.sendMessage(text: text, visitorId: visitorId)
      } else {
        try? await client.sendMessageWithAttachments(
          text: text, attachments: filesToSend, visitorId: visitorId
        )
      }
      isSending = false
    }
  }

  private func scrollToBottom(proxy: ScrollViewProxy) {
    withCossistantAnimation(.easeOut(duration: 0.2)) {
      proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
    }
  }

  private func rebuildItemGroups() {
    itemGroups = ChatItemFormatter.makeGroups(from: timeline.visibleItems)
  }
}

private struct PreparedTimelineItem: Identifiable {
  let id: String
  let item: TimelineItem
  let createdAt: Date?
  let formattedTime: String
}

private struct ChatItemGroup: Identifiable {
  enum Kind: Equatable {
    case message(GroupSenderKey)
    case tool
    case event
    case single
  }

  let id: String
  let kind: Kind
  var items: [PreparedTimelineItem]
}

private enum GroupSenderKey: Equatable {
  case visitor(String)
  case user(String)
  case ai(String)
}

private enum ChatItemFormatter {
  private static let groupingInterval: TimeInterval = 300

  static func makeGroups(from items: [TimelineItem]) -> [ChatItemGroup] {
    var groups: [ChatItemGroup] = []

    for (index, item) in items.enumerated() {
      let prepared = PreparedTimelineItem(
        id: item.id ?? "timeline-item-\(index)-\(item.createdAt)",
        item: item,
        createdAt: SupportFormatters.parseISO8601(item.createdAt),
        formattedTime: formattedTime(for: item.createdAt)
      )

      if let lastIndex = groups.indices.last, canAppend(prepared, to: groups[lastIndex]) {
        groups[lastIndex].items.append(prepared)
      } else {
        groups.append(
          ChatItemGroup(
            id: "group-\(prepared.id)",
            kind: groupKind(for: item),
            items: [prepared]
          )
        )
      }
    }

    return groups
  }

  private static func groupKind(for item: TimelineItem) -> ChatItemGroup.Kind {
    switch item.type {
    case .message:
      if let sender = senderKey(for: item) {
        return .message(sender)
      }
      return .single
    case .tool:
      return .tool
    case .event:
      return .event
    case .identification:
      return .single
    }
  }

  private static func canAppend(_ item: PreparedTimelineItem, to group: ChatItemGroup) -> Bool {
    switch (group.kind, groupKind(for: item.item)) {
    case (.message(let lhsSender), .message(let rhsSender)):
      guard lhsSender == rhsSender, let previous = group.items.last?.createdAt else {
        return false
      }
      guard let current = item.createdAt else { return false }
      return current.timeIntervalSince(previous) < groupingInterval
    case (.tool, .tool):
      return true
    case (.event, .event):
      return true
    default:
      return false
    }
  }

  private static func senderKey(for item: TimelineItem) -> GroupSenderKey? {
    if let visitorId = item.visitorId {
      return .visitor(visitorId)
    }
    if let userId = item.userId {
      return .user(userId)
    }
    if let aiAgentId = item.aiAgentId {
      return .ai(aiAgentId)
    }
    return nil
  }

  private static func formattedTime(for createdAt: String) -> String {
    guard let date = SupportFormatters.parseISO8601(createdAt) else { return "" }
    return SupportFormatters.timeOnly.string(from: date)
  }
}

private struct ItemGroupView: View {
  let group: ChatItemGroup
  let visitorId: String?
  let agents: AgentRegistry

  var body: some View {

    switch group.kind {
    case .message:
      messageGroup
    case .tool:
      toolGroup
    case .event:
      eventGroup
    case .single:
      singleGroup
    }
  }

  private var messageGroup: some View {
    let isFromVisitor = group.items.first?.item.visitorId == visitorId && group.items.first?.item.visitorId != nil

    return VStack(spacing: 4) {
      ForEach(Array(group.items.enumerated()), id: \.element.id) { index, prepared in
        MessageBubbleView(
          item: prepared.item,
          visitorId: visitorId,
          agents: agents,
          showsAgentIdentity: !isFromVisitor && index == 0,
          showsTimestamp: index == group.items.count - 1,
          formattedTime: prepared.formattedTime
        )
        .id(prepared.id)
      }
    }
  }

  private var toolGroup: some View {
    VStack(spacing: 4) {
      ForEach(group.items) { prepared in
        ToolActivityBubbleView(item: prepared.item)
          .id(prepared.id)
      }
    }
  }

  private var eventGroup: some View {
    VStack(spacing: 4) {
      ForEach(group.items) { prepared in
        EventBubbleView(
          item: prepared.item,
          senderInfo: agents.sender(for: prepared.item)
        )
        .id(prepared.id)
      }
    }
  }

  private var singleGroup: some View {
    VStack(spacing: 4) {
      ForEach(group.items) { prepared in
        MessageBubbleView(
          item: prepared.item,
          visitorId: visitorId,
          agents: agents,
          showsAgentIdentity: prepared.item.visitorId == nil,
          showsTimestamp: true,
          formattedTime: prepared.formattedTime
        )
        .id(prepared.id)
      }
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
    ("🛟", false, 0.3, -3, -2, 1.03),
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

  @Environment(\.cossistantDesign) private var design

  var body: some View {

    HStack {
      HStack(spacing: 8) {
        AnimatedDotsView(style: .pulse, dotSize: 5, spacing: 3)

        Text(phaseLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(design.accentColor.opacity(0.08))
      .clipShape(.rect(cornerRadius: 16))
      Spacer()
    }
  }

  private var phaseLabel: String {
    if let message, !message.isEmpty { return message }
    switch phase {
    case "thinking": return R.string(.ai_phase_thinking)
    case "searching": return R.string(.ai_phase_searching)
    case "generating": return R.string(.ai_phase_generating)
    case let p?: return p.capitalized
    default: return R.string(.ai_phase_default)
    }
  }
}

// MARK: - Attachment Preview Strip

private struct AttachmentPreviewStrip: View {
  let attachments: [FileAttachment]
  let onRemove: (UUID) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(attachments) { attachment in
          AttachmentThumbnail(attachment: attachment) {
            onRemove(attachment.id)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }
}

private struct AttachmentThumbnail: View {
  let attachment: FileAttachment
  let onRemove: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if attachment.isImage {
        imagePreview
      } else {
        filePreview
      }

      Button(action: onRemove) {
        Image(systemSymbol: .xmarkCircleFill)
          .font(.system(size: 18))
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, .black.opacity(0.6))
      }
      .offset(x: 6, y: -6)
      .accessibilityLabel(R.string(.attachment_remove))
    }
    .accessibilityLabel(attachment.fileName)
  }

  private var imagePreview: some View {
    DataImageView(data: attachment.data, size: CGSize(width: 60, height: 60))
  }

  private var filePreview: some View {
    VStack(spacing: 2) {
      Image(systemSymbol: .docFill)
        .font(.title3)
        .foregroundStyle(.secondary)
      Text(attachment.fileName)
        .font(.caption2)
        .lineLimit(1)
        .truncationMode(.middle)
      Text(formattedSize)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(width: 60, height: 60)
    .background(.secondary.opacity(0.08))
    .clipShape(.rect(cornerRadius: 8))
  }

  private var formattedSize: String {
    ByteCountFormatter.string(
      fromByteCount: Int64(attachment.fileSizeBytes),
      countStyle: .file
    )
  }
}

// MARK: - Seen Indicator

private struct SeenIndicatorView: View {
  let receipts: [SeenReceipt]

  var body: some View {
    HStack(spacing: 4) {
      Spacer()
      HStack(spacing: -4) {
        ForEach(receipts.prefix(3)) { receipt in
          seenAvatar(for: receipt)
            .overlay(RoundedRectangle(cornerRadius: 18 * 0.3).stroke(.background, lineWidth: 1.5))
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

  private func seenAvatar(for receipt: SeenReceipt) -> some View {
    let info = AgentInfo(
      id: receipt.actorId,
      name: receipt.name ?? "?",
      image: receipt.image,
      kind: receipt.actorType == .aiAgent ? .ai : .human,
      onlineStatus: .offline
    )
    return AgentAvatarView(info: info, size: 18)
  }
}

// MARK: - Scroll Down Indicator

private struct ScrollDownIndicatorModifier: ViewModifier {
  @Binding var isNearBottom: Bool
  let onScrollDown: () -> Void

  @State private var chevronBob = false

  func body(content: Content) -> some View {
    if #available(iOS 18.0, macOS 15.0, *) {
      content
        .onScrollGeometryChange(
          for: Bool.self,
          of: { geo in
            let distanceFromBottom = geo.contentSize.height - geo.containerSize.height - geo.contentOffset.y
            return distanceFromBottom <= 800
          },
          action: { _, newValue in isNearBottom = newValue }
        )
        .overlay(alignment: .bottomTrailing) {
          scrollDownButton
        }
    } else {
      content
    }
  }

  private var scrollDownButton: some View {
    Button(action: onScrollDown) {
      Image(systemSymbol: .arrowDown)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
        .offset(y: chevronBob ? 2 : -1)
        .frame(width: 36, height: 36)
        .background(.regularMaterial)
        .clipShape(.circle)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .scaleEffect(chevronBob ? 1 : 0.95)
    }
    .buttonStyle(HapticButtonStyle())
    .padding(.trailing, 16)
    .padding(.bottom, 8)
    .opacity(isNearBottom ? 0 : 1)
    .offset(y: isNearBottom ? 20 : 0)
    .animation(.easeInOut(duration: 0.25), value: isNearBottom)
    .allowsHitTesting(!isNearBottom)
    .onAppear {
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
        chevronBob = true
      }
    }
  }
}
