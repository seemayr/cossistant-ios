import SwiftUI
import SFSafeSymbols

/// Rating prompt shown instead of the input bar when a conversation is resolved.
struct ConversationRatingView: View {
  let existingRating: Int?
  let onSubmit: (Int, String?) async -> Void

  @State private var selectedRating: Int? = nil
  @State private var comment = ""
  @State private var isSubmitting = false
  @State private var hasSubmitted = false
  @State private var animatedStars = 0
  @State private var settled = false

  private var isLocked: Bool {
    existingRating != nil || hasSubmitted
  }

  private var displayRating: Int? {
    existingRating ?? selectedRating
  }

  var body: some View {
    VStack(spacing: 12) {
      if isLocked {
        thanksState
      } else {
        ratingState
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .padding(.horizontal, 16)
    .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
    .task {
      for i in 1...5 {
        try? await Task.sleep(for: .milliseconds(35 * i))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
          animatedStars = i
        }
      }
      try? await Task.sleep(for: .milliseconds(250))
      withAnimation(.easeOut(duration: 0.12)) {
        settled = true
      }
    }
  }

  // MARK: - Rating State

  private var ratingState: some View {
    VStack(spacing: 6) {
      Text(R.string(.rating_prompt))
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      starRow

      if selectedRating != nil {
        commentField
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  // MARK: - Thanks State

  private var thanksState: some View {
    VStack(spacing: 4) {
      Text(R.string(.rating_thanks))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      
      if let rating = displayRating {
        HStack(spacing: 2) {
          ForEach(1...5, id: \.self) { i in
            Image(systemSymbol: i <= rating ? .starFill : .star)
              .font(.caption2)
              .foregroundStyle(i <= rating ? .orange : .secondary.opacity(0.3))
          }
        }
      }
    }
  }

  // MARK: - Stars

  private var starRow: some View {
    HStack(spacing: 6) {
      ForEach(1...5, id: \.self) { index in
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedRating == index {
              selectedRating = nil
            } else {
              selectedRating = index
            }
          }
          if selectedRating != nil {
            SupportHaptics.play(.buttonTap)
          }
        } label: {
          Image(systemSymbol: starSymbol(for: index))
            .font(.title)
            .foregroundStyle(starColor(for: index))
            .scaleEffect(index <= animatedStars ? 1 : 0.01)
            .opacity(index <= animatedStars ? 1 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: animatedStars)
      }
    }
  }

  private func starSymbol(for index: Int) -> SFSymbol {
    if !settled && index <= animatedStars { return .starFill }
    return index <= (displayRating ?? 0) ? .starFill : .star
  }

  private func starColor(for index: Int) -> Color {
    if !settled && index <= animatedStars { return .orange }
    guard index <= (displayRating ?? 0) else { return .secondary.opacity(0.3) }
    switch displayRating {
    case 1: return .red
    case 2: return .orange
    case 3: return .yellow
    case 4: return .mint
    default: return .orange
    }
  }

  // MARK: - Comment + Submit

  private var commentField: some View {
    VStack(spacing: 10) {
      TextField(R.string(.rating_comment_placeholder), text: $comment, axis: .vertical)
        .textFieldStyle(.plain)
        .lineLimit(2...4)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
        .font(.subheadline)

      Button {
        guard let rating = selectedRating else { return }
        isSubmitting = true
        Task {
          await onSubmit(rating, comment.isEmpty ? nil : comment)
          isSubmitting = false
          withAnimation(.snappy) {
            hasSubmitted = true
          }
          SupportHaptics.play(.conversationCreated)
        }
      } label: {
        Group {
          if isSubmitting {
            ProgressView()
              .tint(.white)
          } else {
            Text(R.string(.rating_submit))
          }
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.tint, in: .rect(cornerRadius: 10))
      }
      .buttonStyle(HapticButtonStyle())
      .disabled(selectedRating == nil || isSubmitting)
      .opacity(selectedRating == nil ? 0.5 : 1)
    }
  }
}
