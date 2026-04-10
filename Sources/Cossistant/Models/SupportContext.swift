import Foundation

public struct SupportIdentity: Sendable, Equatable, Hashable {
  public let externalId: String?
  public let email: String?
  public let name: String?
  public let image: String?

  public init(
    externalId: String? = nil,
    email: String? = nil,
    name: String? = nil,
    image: String? = nil
  ) {
    self.externalId = externalId
    self.email = email
    self.name = name
    self.image = image
  }

  public var isEmpty: Bool {
    externalId == nil && email == nil && name == nil && image == nil
  }
}

/// Context for opening support with durable contact metadata plus
/// conversation-scoped metadata sent when a new conversation is created.
///
/// Usage from a game loading screen:
/// ```swift
/// SupportView(
///   client: client,
///   autoCreate: SupportContext(
///     source: "game_loading",
///     autoCreateConversation: true,
///     contactMetadata: ["platform": .string("iOS")],
///     conversationContext: [
///       "gameId": .string("game_123"),
///       "groupId": .string("group_456"),
///     ],
///     initialMessage: "I'm having trouble loading a game."
///   )
/// )
/// ```
public struct SupportContext: Sendable, Equatable, Hashable {
  /// Where the support request originated (e.g. "settings", "game_loading", "group_view").
  public let source: String

  /// Whether support should jump straight into a new conversation on first open.
  public let autoCreateConversation: Bool

  /// Optional identity used to link the current visitor to a contact.
  public let identity: SupportIdentity?

  /// Durable support/contact metadata that should be attached to the contact record.
  public let contactMetadata: VisitorMetadata

  /// Conversation-scoped metadata attached to the conversation create request.
  public let conversationContext: VisitorMetadata

  /// Optional pre-filled first message from the visitor.
  public let initialMessage: String?

  public init(
    source: String,
    autoCreateConversation: Bool = false,
    identity: SupportIdentity? = nil,
    contactMetadata: VisitorMetadata = VisitorMetadata(),
    conversationContext: VisitorMetadata = VisitorMetadata(),
    initialMessage: String? = nil
  ) {
    var conversationContext = conversationContext
    if conversationContext["source"] == nil {
      conversationContext["source"] = .string(source)
    }

    self.source = source
    self.autoCreateConversation = autoCreateConversation
    self.identity = identity?.isEmpty == true ? nil : identity
    self.contactMetadata = contactMetadata
    self.conversationContext = conversationContext
    self.initialMessage = initialMessage
  }
}
