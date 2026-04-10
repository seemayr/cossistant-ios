import Foundation

/// Configurable text content for the Cossistant support UI.
///
/// Set ``current`` once during app setup to override default strings or show
/// optional hints. All properties default to `nil`, which uses the SDK's
/// built-in localized strings.
///
/// ```swift
/// CossistantContent.current = CossistantContent(
///   emptyChatHumanNote: "We're a solo dev — replies may take a day or two!",
///   participationWaitingHint: "Our team was notified. We're a small crew — thanks for your patience!",
///   supportPreparationWarningTitle: "Details unavailable"
/// )
/// ```
public struct CossistantContent: Sendable {
  /// Overrides the chat empty-state description (first line below the title).
  /// Default: localized "You'll get an instant answer from our knowledge base."
  public var emptyChatDescription: String?

  /// Overrides the human-review note shown in the empty chat state and below
  /// messages when no human agent has participated yet.
  /// Default: localized "A real person reviews every conversation and will reach out if needed."
  public var emptyChatHumanNote: String?

  /// Overrides the conversation list empty-state description.
  /// Default: localized "Start a conversation to get help or share your thoughts with us!"
  public var emptyConversationsDescription: String?

  /// Text shown below the `participant_requested` event bubble. Use this to set
  /// expectations about response times (e.g. "We're a small team — thanks for your patience!").
  /// Default: localized "Someone from our team will take a look. Hang tight — we'll get back to you!"
  public var participationWaitingHint: String?

  /// Overrides the shared title shown when support details could not be attached.
  /// Default: "Details unavailable"
  public var supportPreparationWarningTitle: String?

  /// Overrides the message shown when the visitor could not be identified.
  /// Default: "You can still contact support, but we couldn't attach your account details right now."
  public var supportPreparationIdentificationMessage: String?

  /// Overrides the message shown when support metadata or context could not be attached.
  /// Default: "You can still contact support, but some support details may be missing."
  public var supportPreparationDetailsMessage: String?

  public init(
    emptyChatDescription: String? = nil,
    emptyChatHumanNote: String? = nil,
    emptyConversationsDescription: String? = nil,
    participationWaitingHint: String? = nil,
    supportPreparationWarningTitle: String? = nil,
    supportPreparationIdentificationMessage: String? = nil,
    supportPreparationDetailsMessage: String? = nil
  ) {
    self.emptyChatDescription = emptyChatDescription
    self.emptyChatHumanNote = emptyChatHumanNote
    self.emptyConversationsDescription = emptyConversationsDescription
    self.participationWaitingHint = participationWaitingHint
    self.supportPreparationWarningTitle = supportPreparationWarningTitle
    self.supportPreparationIdentificationMessage = supportPreparationIdentificationMessage
    self.supportPreparationDetailsMessage = supportPreparationDetailsMessage
  }

  /// The active content configuration. Set once during app setup.
  nonisolated(unsafe) public static var current = CossistantContent()
}
