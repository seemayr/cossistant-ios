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
        .transition(.listRow)
      }

      if conversations.hasMore {
        Button(action: {
          Task { try? await conversations.loadMore() }
        }, label: {
          HStack(spacing: 4) {
            Image(systemSymbol: .ellipsisRectangle)
            Text(R.string(.load_more))
          }
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(Color.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(Color.black.opacity(0.3))
          .clipShape(.rect(cornerRadius: 8))
        })
        .buttonStyle(HapticButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowSeparator(.hidden)
        .transition(.fadeInScale)
      }
    }
    .listStyle(.plain)
    .cossistantAnimation(CossistantAnimation.smooth, value: conversations.sorted.map(\.id))
    .cossistantAnimation(CossistantAnimation.smooth, value: conversations.hasMore)
    .overlay {
      if conversations.isLoading && conversations.conversations.isEmpty {
        SupportLoadingOverlayView(R.string(.loading_conversations))
      } else if !conversations.hasDisplayableConversations {
        ConversationListEmptyView()
          .padding(.bottom, 48)
          .transition(.fadeInScale)
      }
    }
    .safeAreaInset(edge: .bottom) {
      newConversationCTA
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
    .padding(.vertical, 16)
    .background(.regularMaterial)
  }
}

// MARK: - Empty State

private struct ConversationListEmptyView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  @State private var floating = false

  var body: some View {
    VStack(spacing: 28) {
      VStack(spacing: 10) {
        ghostCard(lineWidth: 110, entranceDelay: 0, drift: 9, floatDuration: 2.8)
        ghostCard(lineWidth: 80, entranceDelay: 0.08, drift: -11, floatDuration: 3.2)
        ghostCard(lineWidth: 100, entranceDelay: 0.16, drift: 6, floatDuration: 2.5)
      }
      .padding(.horizontal, 54)

      VStack(spacing: 6) {
        Text(R.string(.empty_conversations_title))
          .font(.title3.weight(.semibold))

        Text(R.string(.empty_conversations_description))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 32)
      .opacity(appeared ? 1 : 0)
      .offset(y: appeared ? 0 : 10)
      .animation(
        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(0.25),
        value: appeared
      )
    }
    .task {
      appeared = true
      try? await Task.sleep(for: .milliseconds(700))
      floating = true
    }
  }

  private func ghostCard(lineWidth: CGFloat, entranceDelay: Double, drift: CGFloat, floatDuration: Double) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(.secondary.opacity(0.2))
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 6) {
        RoundedRectangle(cornerRadius: 3)
          .fill(.secondary.opacity(0.15))
          .frame(width: lineWidth, height: 10)
        RoundedRectangle(cornerRadius: 3)
          .fill(.secondary.opacity(0.1))
          .frame(width: lineWidth * 0.65, height: 7)
      }

      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 14))
    .opacity(appeared ? 1 : 0)
    .offset(x: floating ? drift : 0)
    .offset(y: appeared ? 0 : 12)
    .animation(
      reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7).delay(entranceDelay),
      value: appeared
    )
    .animation(
      reduceMotion ? nil : .easeInOut(duration: floatDuration)
        .repeatForever(autoreverses: true)
        .delay(entranceDelay),
      value: floating
    )
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
        .fontWeight(.regular)
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
    guard let date = SupportFormatters.parseISO8601( conversation.updatedAt) else { return "" }
    return SupportFormatters.relativeDate.localizedString(for: date, relativeTo: Date())
  }
}
