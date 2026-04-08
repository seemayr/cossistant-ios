import SwiftUI
import SFSafeSymbols

/// Routes to the correct bubble type based on item type and sender.
struct MessageBubbleView: View {
  let item: TimelineItem
  let isFromVisitor: Bool
  let senderInfo: AgentInfo?
  let showsAgentIdentity: Bool
  let showsTimestamp: Bool
  let formattedTime: String
  
  init(
    item: TimelineItem,
    visitorId: String?,
    agents: AgentRegistry,
    showsAgentIdentity: Bool = false,
    showsTimestamp: Bool = false,
    formattedTime: String = ""
  ) {
    self.item = item
    self.isFromVisitor = item.visitorId != nil && item.visitorId == visitorId
    self.senderInfo = agents.sender(for: item)
    self.showsAgentIdentity = showsAgentIdentity
    self.showsTimestamp = showsTimestamp
    self.formattedTime = formattedTime
  }
  
  var body: some View {

    if item.type == .event {
      EventBubbleView(item: item, senderInfo: senderInfo)
    } else if item.type == .tool {
      ToolActivityBubbleView(item: item)
    } else if isFromVisitor {
      VisitorBubbleView(
        item: item,
        showsTimestamp: showsTimestamp,
        formattedTime: formattedTime
      )
    } else {
      AgentBubbleView(
        item: item,
        senderInfo: senderInfo,
        showsIdentity: showsAgentIdentity,
        showsTimestamp: showsTimestamp,
        formattedTime: formattedTime
      )
    }
  }
}

// MARK: - Visitor Bubble (right-aligned, tint background)

private struct VisitorBubbleView: View {
  let item: TimelineItem
  let showsTimestamp: Bool
  let formattedTime: String
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Spacer(minLength: 40)
      
      VStack(alignment: .trailing, spacing: -6) {
        VStack(alignment: .trailing, spacing: 4) {
          if let text = item.text, !text.isEmpty {
            Text(text)
              .font(.body)
              .foregroundStyle(.white)
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(.tint)
              .clipShape(.rect(cornerRadius: 16))
              .contextMenu { MessageContextMenu(text: text) }
              .zIndex(1)
          }

          if !item.parts.isEmpty {
            RichPartsView(parts: item.parts, itemText: item.text, isFromVisitor: true)
              .zIndex(1)
          }
        }
        
        if showsTimestamp, !formattedTime.isEmpty {
          Text(formattedTime)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .foregroundStyle(.primary)
            .background(.background.tertiary)
            .clipShape(.rect(cornerRadius: 6))
            .opacity(0.7)
            .padding(.horizontal, 4)
            .zIndex(2)
        }
      }
    }
  }
}

// MARK: - Agent Bubble (left-aligned, secondary background, avatar)

private struct AgentBubbleView: View {
  let item: TimelineItem
  let senderInfo: AgentInfo?
  let showsIdentity: Bool
  let showsTimestamp: Bool
  let formattedTime: String
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if showsIdentity {
        AgentAvatarView(info: senderInfo, size: 28)
      } else {
        Color.clear
          .frame(width: 28, height: 0)
      }
      
      VStack(alignment: .leading, spacing: -6) {
        VStack(alignment: .leading, spacing: 4) {
          if showsIdentity, let name = senderInfo?.name {
            Text(name)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundStyle(.secondary)
          }
          
          if let text = item.text, !text.isEmpty {
            Text(text)
              .font(.body)
              .foregroundStyle(.primary)
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(.secondary.opacity(0.12))
              .clipShape(.rect(cornerRadius: 16))
              .contextMenu { MessageContextMenu(text: text) }
              .zIndex(1)
          }
          
          if !item.parts.isEmpty {
            RichPartsView(parts: item.parts, itemText: item.text, isFromVisitor: false)
          }
        }
        
        if showsTimestamp, !formattedTime.isEmpty {
          Text(formattedTime)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .foregroundStyle(.primary)
            .background(.background.tertiary)
            .clipShape(.rect(cornerRadius: 6))
            .opacity(0.7)
            .padding(.horizontal, 4)
            .zIndex(2)
        }
      }
      
      Spacer(minLength: 40)
    }
  }
}

// MARK: - Rich Parts (shared between visitor & agent)

private struct RichPartsView: View {
  let parts: [TimelineItemPart]
  let itemText: String?
  let isFromVisitor: Bool
  
  var body: some View {
    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
      switch part {
      case .text(let textPart):
        // Only render from part when item.text is missing (e.g. streaming)
        if (itemText == nil || itemText?.isEmpty == true) && !textPart.text.isEmpty {
          Text(textPart.text)
            .font(.body)
            .foregroundStyle(isFromVisitor ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isFromVisitor ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.12)))
            .clipShape(.rect(cornerRadius: 16))
            .contextMenu { MessageContextMenu(text: textPart.text) }
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
  }
}

// MARK: - Event Bubble

struct EventBubbleView: View {
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
      .fontWeight(.medium)
      .foregroundStyle(.purple.opacity(0.9))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(.purple.opacity(0.08))
      .clipShape(.capsule)
      .overlay {
        Capsule()
          .stroke(Color.purple.opacity(0.5), lineWidth: 1.2)
      }
      
      Spacer()
    }
    .padding(.vertical, 12)
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
    case "reopened":
      Image(systemSymbol: .arrowUturnForwardCircleFill)
    case "participant_joined":
      Image(systemSymbol: .personBadgePlus)
    case "participant_left":
      Image(systemSymbol: .personBadgeMinus)
    case "assigned":
      Image(systemSymbol: .personCropCircleBadgeCheckmark)
    case "visitor_identified":
      Image(systemSymbol: .personCropCircleFill)
    default:
      Image(systemSymbol: .infoCircleFill)
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

// MARK: - Tool Activity Bubble

struct ToolActivityBubbleView: View {
  let item: TimelineItem
  
  var body: some View {
    HStack(spacing: 4) {
      indicator
      Text(toolLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
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
    if let text = item.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty {
      return text
    }
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

// MARK: - Agent Avatar

struct AgentAvatarView: View {
  let info: AgentInfo?
  let size: CGFloat
  
  private var isAI: Bool { info?.kind == .ai }
  
  var body: some View {
    if isAI {
      aiAvatar
    } else if let imageURL = info?.image, let url = URL(string: imageURL) {
      AsyncImage(url: url) { image in
        image.resizable()
      } placeholder: {
        initialsView
      }
      .frame(width: size, height: size)
      .clipShape(.rect(cornerRadius: size * 0.3))
    } else {
      initialsView
    }
  }
  
  // MARK: AI Avatar
  
  @ViewBuilder
  private var aiAvatar: some View {
    if let imageURL = info?.image, let url = URL(string: imageURL) {
      AsyncImage(url: url) { image in
        image.resizable()
      } placeholder: {
        aiLogoView
      }
      .frame(width: size, height: size)
      .clipShape(.rect(cornerRadius: size * 0.3))
    } else {
      aiLogoView
    }
  }
  
  private var aiLogoView: some View {
    RoundedRectangle(cornerRadius: size * 0.3)
      .fill(.secondary.opacity(0.12))
      .frame(width: size, height: size)
      .overlay {
        Image("coss", bundle: .module)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: size * 0.5, height: size * 0.5)
          .foregroundStyle(.secondary)
      }
  }
  
  // MARK: Human Avatar
  
  private var initialsView: some View {
    RoundedRectangle(cornerRadius: size * 0.3)
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

// MARK: - Message Context Menu

/// Context menu actions for text message bubbles.
private struct MessageContextMenu: View {
  let text: String

  var body: some View {
    Button {
      #if os(iOS)
      UIPasteboard.general.string = text
      #elseif os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
      #endif
      SupportHaptics.play(.buttonTap)
    } label: {
      Label(R.string(.context_copy), systemSymbol: .docOnDoc)
    }
  }
}
