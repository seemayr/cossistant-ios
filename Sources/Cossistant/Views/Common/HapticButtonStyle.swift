import SwiftUI

/// Button style providing haptic feedback on press with a subtle scale animation.
/// Pass a specific haptic pattern to match the button's semantic purpose.
struct HapticButtonStyle: ButtonStyle {
  let haptic: SupportHaptics.Pattern

  init(haptic: SupportHaptics.Pattern = .buttonTap) {
    self.haptic = haptic
  }

  func makeBody(configuration: ButtonStyle.Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.9 : 1)
      .onChange(of: configuration.isPressed) { _, isPressed in
        if isPressed {
          SupportHaptics.play(haptic)
        }
      }
      .animation(.snappy(duration: 0.15), value: configuration.isPressed)
  }
}
