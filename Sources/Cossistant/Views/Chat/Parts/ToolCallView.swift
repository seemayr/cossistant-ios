import SwiftUI
import SFSafeSymbols

/// Renders a tool call with visual state: in-progress spinner, completed checkmark, or error.
struct ToolCallView: View {
  let tool: ToolPart

  var body: some View {
    HStack(spacing: 6) {
      stateIcon
      Text(displayName)
        .font(.caption)
        .foregroundStyle(isError ? .red : .secondary)
      if isPartial {
        ToolDotsView()
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(backgroundFill, in: .capsule)
    .transition(.fadeInScale)
  }

  // MARK: - State

  private var isPartial: Bool { tool.state == "partial" }
  private var isError: Bool { tool.state == "error" }

  private var displayName: String {
    tool.toolName
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  @ViewBuilder
  private var stateIcon: some View {
    switch tool.state {
    case "partial":
      EmptyView()
    case "error":
      Image(systemSymbol: .xmarkCircleFill)
        .font(.caption)
        .foregroundStyle(.red)
    default:
      Image(systemSymbol: .checkmarkCircleFill)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var backgroundFill: some ShapeStyle {
    isError
      ? AnyShapeStyle(.red.opacity(0.08))
      : AnyShapeStyle(.secondary.opacity(0.08))
  }
}

// MARK: - Animated Dots (small inline spinner)

private struct ToolDotsView: View {
  @State private var isAnimating = false

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(.secondary)
          .frame(width: 4, height: 4)
          .opacity(isAnimating ? 1 : 0.3)
          .animation(
            .easeInOut(duration: 0.5)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.15),
            value: isAnimating
          )
      }
    }
    .onAppear { isAnimating = true }
  }
}
