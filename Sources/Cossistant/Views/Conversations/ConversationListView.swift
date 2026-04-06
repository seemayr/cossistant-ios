import SwiftUI
import SFSafeSymbols

/// List of conversations with swipe actions, sorted open-first, and a bottom CTA.
public struct ConversationListView: View {
  private let conversations: ConversationStore
  private let agents: AgentRegistry
  private let connection: ConnectionStore
  private let timeline: TimelineStore
  private let visitorId: String?
  private let onSelect: (Conversation) -> Void
  private let onNewConversation: () -> Void

  public init(
    conversations: ConversationStore,
    agents: AgentRegistry,
    connection: ConnectionStore,
    timeline: TimelineStore,
    visitorId: String?,
    onSelect: @escaping (Conversation) -> Void,
    onNewConversation: @escaping () -> Void
  ) {
    self.conversations = conversations
    self.agents = agents
    self.connection = connection
    self.timeline = timeline
    self.visitorId = visitorId
    self.onSelect = onSelect
    self.onNewConversation = onNewConversation
  }

  public var body: some View {
    List {
      ForEach(conversations.sorted) { conversation in
        Button { onSelect(conversation) } label: {
          ConversationRowView(
            conversation: conversation,
            agents: agents,
            connection: connection
          )
        }
        .buttonStyle(HapticButtonStyle())
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .swipeActions(edge: .trailing) {
          Button {
            SupportHaptics.play(.buttonTap)
            Task {
              try? await timeline.load(conversationId: conversation.id)
              try? await timeline.markSeen()
              timeline.clear()
            }
          } label: {
            Label(R.string(.swipe_mark_read), systemSymbol: .eyeFill)
          }
          .tint(.blue)
        }
        .swipeActions(edge: .leading) {
          if conversation.status == .open {
            NavigationLink(value: conversation.id) {
              Label(R.string(.swipe_rate), systemSymbol: .starFill)
            }
            .tint(.orange)
          }
        }
      }

      if conversations.hasMore {
        Button(R.string(.load_more)) {
          Task { try? await conversations.loadMore() }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .buttonStyle(HapticButtonStyle())
      }
    }
    .listStyle(.plain)
    .safeAreaInset(edge: .bottom) {
      newConversationCTA
    }
    .overlay {
      if conversations.isLoading && conversations.conversations.isEmpty {
        SupportLoadingOverlayView(R.string(.loading_conversations))
      } else if conversations.conversations.isEmpty {
        emptyState
      }
    }
  }

  // MARK: - Bottom CTA

  private var newConversationCTA: some View {
    Button(action: onNewConversation) {
      Label(R.string(.new_conversation_cta), systemSymbol: .plusBubbleFill)
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.tint, in: .rect(cornerRadius: 12))
    }
    .buttonStyle(HapticButtonStyle())
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.regularMaterial)
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label(R.string(.empty_conversations_title), systemSymbol: .bubbleLeftAndBubbleRight)
        .symbolEffect(.pulse, options: .repeating.speed(0.5))
    } description: {
      Text(R.string(.empty_conversations_description))
    }
    .transition(.fadeInScale)
  }
}

// MARK: - Row (separate struct for performance)

private struct ConversationRowView: View {
  let conversation: Conversation
  let agents: AgentRegistry
  let connection: ConnectionStore

  var body: some View {
    HStack(spacing: 12) {
      avatarWithStatus
      details
    }
    .padding(.vertical, 4)
    .opacity(conversation.status == .resolved ? 0.7 : 1)
  }

  // MARK: - Avatar

  private var lastAgent: AgentInfo? {
    guard let lastItem = conversation.lastTimelineItem else { return nil }
    return agents.sender(for: lastItem)
  }

  private var avatarWithStatus: some View {
    let agent = lastAgent ?? agents.allAgents.first
    return ZStack(alignment: .bottomTrailing) {
      AgentAvatarView(info: agent, size: 40)

      if let status = agent?.onlineStatus, status != .offline {
        Circle()
          .fill(status == .online ? .green : .orange)
          .frame(width: 10, height: 10)
          .overlay(Circle().stroke(.background, lineWidth: 2))
      }
    }
  }

  // MARK: - Details

  private var details: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(conversation.title ?? R.string(.conversation_default_title))
          .font(.headline)
          .lineLimit(1)

        Spacer()

        statusBadge
      }

      subtitle

      Text(formattedDate)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }

  @ViewBuilder
  private var subtitle: some View {
    if connection.isAgentTyping(in: conversation.id),
       let name = connection.typingAgentName(for: conversation.id) {
      Text(R.string(.typing_indicator, name))
        .font(.subheadline)
        .foregroundStyle(.tint)
        .lineLimit(1)
    } else if let lastItem = conversation.lastTimelineItem {
      let senderName = lastItem.visitorId != nil
        ? R.string(.sender_you)
        : (agents.sender(for: lastItem)?.name ?? R.string(.sender_default))
      Text("\(senderName): \(lastItem.text ?? "")")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(3)
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    switch conversation.status {
    case .open:
      Text(R.string(.status_open))
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(.green.opacity(0.12))
        .clipShape(.capsule)
    case .resolved:
      HStack(spacing: 3) {
        Image(systemSymbol: .checkmarkCircleFill)
          .font(.caption2)
        Text(R.string(.status_resolved))
          .font(.caption2)
          .fontWeight(.medium)
      }
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
      .background(.secondary.opacity(0.12))
      .clipShape(.capsule)
    case .spam:
      EmptyView()
    }
  }

  private var formattedDate: String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: conversation.updatedAt) else { return "" }
    let display = RelativeDateTimeFormatter()
    display.unitsStyle = .short
    return display.localizedString(for: date, relativeTo: Date())
  }
}
