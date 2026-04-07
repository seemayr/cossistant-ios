import SwiftUI

/// Convenience wrapper that embeds ``SupportView`` inside a `NavigationStack`.
///
/// Use this when presenting `SupportView` in a context that does **not** already
/// provide a `NavigationStack` — for example sheets, fullscreen covers, or standalone windows.
///
/// If the host already provides a `NavigationStack` (e.g. a router push),
/// use ``SupportView`` directly to avoid nesting.
///
/// ```swift
/// .sheet(isPresented: $showSupport) {
///   SupportNavigationView(client: client, onDismiss: { showSupport = false })
/// }
/// ```
public struct SupportNavigationView: View {
  private let client: CossistantClient
  private let autoCreate: SupportContext?
  private let onDismiss: (() -> Void)?

  public init(
    client: CossistantClient,
    autoCreate: SupportContext? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.client = client
    self.autoCreate = autoCreate
    self.onDismiss = onDismiss
  }

  public var body: some View {
    NavigationStack {
      SupportView(
        client: client,
        autoCreate: autoCreate,
        onDismiss: onDismiss
      )
    }
  }
}
