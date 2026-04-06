import SwiftUI
import SFSafeSymbols

/// A single message bubble with sender identity, or a centered event label.
public struct MessageBubbleView: View {
  let item: TimelineItem
  let isFromVisitor: Bool
  let senderInfo: AgentInfo?
  let isGrouped: Bool

  public init(
    item: TimelineItem,
    visitorId: String?,
    agents: AgentRegistry,
    isGrouped: Bool = false
  ) {
    self.item = item
    self.isFromVisitor = item.visitorId != nil && item.visitorId == visitorId
    self.senderInfo = agents.sender(for: item)
    self.isGrouped = isGrouped
  }

  public var body: some View {
    if item.type == .event {
      EventBubbleView(item: item, senderInfo: senderInfo)
    } else if item.type == .tool {
      ToolActivityBubbleView(item: item)
    } else {
      messageBubble
    }
  }

  // MARK: - Message Bubble

  private var messageBubble: some View {
    HStack(alignment: .top, spacing: 8) {
      if isFromVisitor { Spacer(minLength: 40) }

      if !isFromVisitor {
        if isGrouped {
          // Invisible spacer matching avatar width to keep alignment
          Color.clear
            .frame(width: 28, height: 0)
        } else {
          AgentAvatarView(info: senderInfo, size: 28)
        }
      }

      VStack(alignment: isFromVisitor ? .trailing : .leading, spacing: 4) {
        if !isFromVisitor && !isGrouped, let name = senderInfo?.name {
          Text(name)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
        }

        if let text = item.text, !text.isEmpty {
          Text(text)
            .font(.body)
            .foregroundStyle(isFromVisitor ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isFromVisitor ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.12)))
            .clipShape(.rect(cornerRadius: 16))
        }

        // Rich parts
        ForEach(Array(item.parts.enumerated()), id: \.offset) { _, part in
          switch part {
          case .text(let textPart):
            // Only render from part when item.text is missing (e.g. streaming)
            if item.text == nil || item.text?.isEmpty == true {
              Text(textPart.text)
                .font(.body)
                .foregroundStyle(isFromVisitor ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isFromVisitor ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.12)))
                .clipShape(.rect(cornerRadius: 16))
            }
          case .image(let img):
            ImagePartView(image: img)
          case .tool(let tool):
            ToolCallView(tool: tool)
          case .reasoning(let reasoning):
            ReasoningView(reasoning: reasoning)
          case .sourceUrl(let source):
            SourceUrlChipView(source: source)
          case .sourceDocument(let source):
            SourceDocumentChipView(source: source)
          case .file(let file):
            FileCardView(file: file)
          case .event, .metadata, .stepStart, .unknown:
            EmptyView()
          }
        }

        if !isGrouped {
          Text(formattedTime)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }

      if !isFromVisitor { Spacer(minLength: 40) }
    }
  }

  private var formattedTime: String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: item.createdAt) else { return "" }
    let display = DateFormatter()
    display.timeStyle = .short
    return display.string(from: date)
  }
}

// MARK: - Event Bubble (separate struct for performance)

private struct EventBubbleView: View {
  let item: TimelineItem
  let senderInfo: AgentInfo?

  var body: some View {
    HStack {
      Spacer()
      HStack(spacing: 6) {
        eventIcon
        label
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(.secondary.opacity(0.08))
      .clipShape(.capsule)
      Spacer()
    }
    .padding(.vertical, 4)
    .transition(.fadeInScale)
  }

  @ViewBuilder
  private var eventIcon: some View {
    let eventType = item.parts.compactMap { part -> String? in
      if case .event(let e) = part { return e.eventType }
      return nil
    }.first ?? ""

    switch eventType {
    case "resolved":
      Image(systemSymbol: .checkmarkCircleFill)
        .foregroundStyle(.green)
    case "reopened":
      Image(systemSymbol: .arrowUturnForwardCircleFill)
        .foregroundStyle(.orange)
    case "participant_joined":
      Image(systemSymbol: .personBadgePlus)
        .foregroundStyle(.tint)
    case "participant_left":
      Image(systemSymbol: .personBadgeMinus)
        .foregroundStyle(.secondary)
    case "assigned":
      Image(systemSymbol: .personCropCircleBadgeCheckmark)
        .foregroundStyle(.tint)
    case "visitor_identified":
      Image(systemSymbol: .personCropCircleFill)
        .foregroundStyle(.tint)
    default:
      Image(systemSymbol: .infoCircleFill)
        .foregroundStyle(.secondary)
    }
  }

  private var label: Text {
    let name = senderInfo?.name ?? R.string(.event_default_actor)
    for part in item.parts {
      if case .event(let event) = part {
        return switch event.eventType {
        case "resolved": Text(R.string(.event_resolved, name))
        case "reopened": Text(R.string(.event_reopened, name))
        case "participant_joined": Text(R.string(.event_joined, name))
        case "participant_left": Text(R.string(.event_left, name))
        case "assigned": Text(R.string(.event_assigned, name))
        case "visitor_identified": Text(R.string(.event_identified))
        default: Text(event.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
        }
      }
    }
    return Text("")
  }
}

// MARK: - Tool Activity Bubble (searchKnowledgeBase etc.)

private struct ToolActivityBubbleView: View {
  let item: TimelineItem

  var body: some View {
    HStack(spacing: 8) {
      indicator
      Text(toolLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var indicator: some View {
    let state = toolState
    if state == "partial" {
      ProgressView()
        .scaleEffect(0.6)
    } else if state == "error" {
      Image(systemSymbol: .xmarkCircleFill)
        .font(.caption)
        .foregroundStyle(.red)
    } else {
      Image(systemSymbol: .checkmarkCircle)
        .font(.caption)
        .foregroundStyle(.green)
    }
  }

  private var toolState: String {
    for part in item.parts {
      if case .tool(let t) = part { return t.state }
    }
    return "result"
  }

  private var toolLabel: String {
    // Use item.text if available (server-provided summary)
    if let text = item.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty {
      return text
    }
    // Extract query from tool input for searchKnowledgeBase
    let toolName = item.tool ?? "tool"
    let state = toolState
    if state == "partial" {
      return R.string(.ai_phase_searching)
    }
    if state == "error" {
      return "Search failed"
    }
    return "Completed \(toolName)"
  }
}

// MARK: - Agent Avatar (reusable)

struct AgentAvatarView: View {
  let info: AgentInfo?
  let size: CGFloat

  var body: some View {
    if let imageURL = info?.image, let url = URL(string: imageURL) {
      AsyncImage(url: url) { image in
        image.resizable()
      } placeholder: {
        initialsView
      }
      .frame(width: size, height: size)
      .clipShape(.circle)
    } else {
      initialsView
    }
  }

  private var initialsView: some View {
    Circle()
      .fill(.tint.opacity(0.2))
      .frame(width: size, height: size)
      .overlay {
        Text(String((info?.name ?? "?").prefix(1)))
          .font(.system(size: size * 0.4))
          .fontWeight(.semibold)
          .foregroundStyle(.tint)
      }
  }
}
