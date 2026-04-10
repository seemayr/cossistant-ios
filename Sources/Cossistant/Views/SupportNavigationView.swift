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
  private let conversationChannel: String?
  private let supportContext: SupportContext?
  private let onDismiss: (() -> Void)?

  public init(
    client: CossistantClient,
    channel: String? = nil,
    autoCreate: SupportContext? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.client = client
    self.conversationChannel = channel
    self.supportContext = autoCreate
    self.onDismiss = onDismiss
  }

  public var body: some View {
    NavigationStack {
      SupportView(
        client: client,
        channel: conversationChannel,
        autoCreate: supportContext,
        onDismiss: onDismiss
      )
    }
  }
}
