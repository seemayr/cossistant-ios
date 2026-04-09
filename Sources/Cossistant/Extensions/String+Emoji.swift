import Foundation

extension String {
  /// `true` when the string is non-empty and every character is an emoji
  /// (emoji presentation, modifier, modifier base, or zero-width joiner).
  var containsOnlyEmojis: Bool {
    !isEmpty && !contains { character in
      character.unicodeScalars.contains { scalar in
        let isEmojiComponent = scalar.properties.isEmojiPresentation
          || scalar.properties.isEmojiModifier
          || scalar.properties.isEmojiModifierBase
        let isJoiner = scalar.value == 0x200D // Zero Width Joiner
        return !(isEmojiComponent || isJoiner)
      }
    }
  }

  /// Whether this string is a short emoji-only message suitable for scaled display.
  var isScaledEmoji: Bool {
    count <= 4 && containsOnlyEmojis
  }

  /// Font size for emoji-only messages — 50pt for 1 emoji, 25pt for 6.
  var emojiFontSize: CGFloat {
    CGFloat(30 + 5 * (6 - count))
  }
}
