import Foundation

/// Context for auto-creating a support conversation with pre-filled metadata.
/// Pass this to `SupportView` to automatically open a new ticket with context.
///
/// Usage from a game loading screen:
/// ```swift
/// SupportView(
///   client: client,
///   autoCreate: SupportContext(
///     source: "game_loading",
///     metadata: [
///       "gameId": .string("game_123"),
///       "groupId": .string("group_456"),
///       "errorType": .string("load_timeout"),
///     ],
///     initialMessage: "I'm having trouble loading a game."
///   )
/// )
/// ```
public struct SupportContext: Sendable, Equatable, Hashable {
  /// Where the support request originated (e.g. "settings", "game_loading", "group_view").
  public let source: String

  /// Metadata to attach to the conversation. Merged into visitor metadata.
  public let metadata: VisitorMetadata

  /// Optional pre-filled first message from the visitor.
  public let initialMessage: String?

  public init(
    source: String,
    metadata: VisitorMetadata = VisitorMetadata(),
    initialMessage: String? = nil
  ) {
    self.source = source
    self.metadata = metadata
    self.initialMessage = initialMessage
  }
}
