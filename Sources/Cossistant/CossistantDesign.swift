import SwiftUI

/// Visual design tokens for the Cossistant support UI.
///
/// Pass a customized instance via the `.cossistantDesign(_:)` view modifier
/// to override the default appearance. All properties have sensible defaults
/// so you only need to specify what you want to change.
///
/// ```swift
/// SupportNavigationView(client: client)
///   .cossistantDesign(CossistantDesign(accentColor: .purple, fontDesign: .rounded))
/// ```
public struct CossistantDesign: Sendable {
  /// Color used for CTA buttons, visitor message bubbles, and interactive elements.
  public var accentColor: Color

  /// Font design applied to all text (`.rounded`, `.serif`, `.monospaced`, or `.default`).
  public var fontDesign: Font.Design

  public init(
    accentColor: Color = .accentColor,
    fontDesign: Font.Design = .default
  ) {
    self.accentColor = accentColor
    self.fontDesign = fontDesign
  }
}

// MARK: - Environment Key

private struct CossistantDesignKey: EnvironmentKey {
  static let defaultValue = CossistantDesign()
}

extension EnvironmentValues {
  /// The design configuration for the Cossistant support UI.
  public var cossistantDesign: CossistantDesign {
    get { self[CossistantDesignKey.self] }
    set { self[CossistantDesignKey.self] = newValue }
  }
}

// MARK: - View Modifier

extension View {
  /// Configures the visual design of the Cossistant support UI.
  ///
  /// Applies the accent color as the view tint, sets the font design on all
  /// child text, and injects the full ``CossistantDesign`` into the environment
  /// for components that need direct access to the design tokens.
  ///
  /// - Parameter design: The design configuration to apply.
  public func cossistantDesign(_ design: CossistantDesign) -> some View {
    self
      .tint(design.accentColor)
      .fontDesign(design.fontDesign)
      .environment(\.cossistantDesign, design)
  }
}
