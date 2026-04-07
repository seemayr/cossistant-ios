import Foundation
import ULID

// MARK: - Timeline Item

public struct TimelineItem: Codable, Sendable, Identifiable, Equatable {
  public let id: String?
  public let conversationId: String
  public let organizationId: String
  public let visibility: TimelineItemVisibility
  public let type: TimelineItemType
  public let text: String?
  public let tool: String?
  public let parts: [TimelineItemPart]
  public let userId: String?
  public let aiAgentId: String?
  public let visitorId: String?
  public let createdAt: String
  public let deletedAt: String?
}

public enum TimelineItemVisibility: String, Codable, Sendable {
  case `public`
  case `private`
}

public enum TimelineItemType: String, Codable, Sendable {
  case message
  case event
  case identification
  case tool
}

// MARK: - Timeline Item Parts

public enum TimelineItemPart: Codable, Sendable, Equatable {
  case text(TextPart)
  case reasoning(ReasoningPart)
  case tool(ToolPart)
  case sourceUrl(SourceUrlPart)
  case sourceDocument(SourceDocumentPart)
  case stepStart
  case file(FilePart)
  case image(ImagePart)
  case event(EventPart)
  case metadata(MetadataPart)
  case unknown

  private enum TypeKey: String, Codable {
    case text, reasoning, event, metadata, file, image
    case sourceUrl = "source-url"
    case sourceDocument = "source-document"
    case stepStart = "step-start"
  }

  private struct PartTypeContainer: Codable {
    let type: String
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let typeContainer = try container.decode(PartTypeContainer.self)

    switch typeContainer.type {
    case "text":
      self = .text(try container.decode(TextPart.self))
    case "reasoning":
      self = .reasoning(try container.decode(ReasoningPart.self))
    case "source-url":
      self = .sourceUrl(try container.decode(SourceUrlPart.self))
    case "source-document":
      self = .sourceDocument(try container.decode(SourceDocumentPart.self))
    case "step-start":
      self = .stepStart
    case "file":
      self = .file(try container.decode(FilePart.self))
    case "image":
      self = .image(try container.decode(ImagePart.self))
    case "event":
      self = .event(try container.decode(EventPart.self))
    case "metadata":
      self = .metadata(try container.decode(MetadataPart.self))
    default:
      if typeContainer.type.hasPrefix("tool-") {
        self = .tool(try container.decode(ToolPart.self))
      } else {
        self = .unknown
      }
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .text(let part): try container.encode(part)
    case .reasoning(let part): try container.encode(part)
    case .tool(let part): try container.encode(part)
    case .sourceUrl(let part): try container.encode(part)
    case .sourceDocument(let part): try container.encode(part)
    case .stepStart: try container.encode(["type": "step-start"])
    case .file(let part): try container.encode(part)
    case .image(let part): try container.encode(part)
    case .event(let part): try container.encode(part)
    case .metadata(let part): try container.encode(part)
    case .unknown: try container.encode(["type": "unknown"])
    }
  }
}

// MARK: - Part Types

public struct TextPart: Codable, Sendable, Equatable {
  public let type: String
  public let text: String
  public let state: String?

  public init(text: String, state: String? = nil) {
    self.type = "text"
    self.text = text
    self.state = state
  }
}

public struct ReasoningPart: Codable, Sendable, Equatable {
  public let type: String
  public let text: String
  public let state: String?
}

public struct ToolPart: Codable, Sendable, Equatable {
  public let type: String
  public let toolCallId: String
  public let toolName: String
  public let state: String
  public let errorText: String?
}

public struct SourceUrlPart: Codable, Sendable, Equatable {
  public let type: String
  public let sourceId: String
  public let url: String
  public let title: String?
}

public struct SourceDocumentPart: Codable, Sendable, Equatable {
  public let type: String
  public let sourceId: String
  public let mediaType: String
  public let title: String
  public let filename: String?
}

public struct FilePart: Codable, Sendable, Equatable {
  public let type: String
  public let url: String
  public let mediaType: String
  public let filename: String?
  public let size: Int?

  public init(url: String, mediaType: String, filename: String?, size: Int?) {
    self.type = "file"
    self.url = url
    self.mediaType = mediaType
    self.filename = filename
    self.size = size
  }
}

public struct ImagePart: Codable, Sendable, Equatable {
  public let type: String
  public let url: String
  public let mediaType: String
  public let filename: String?
  public let size: Int?
  public let width: Int?
  public let height: Int?

  public init(url: String, mediaType: String, filename: String?, size: Int?,
              width: Int? = nil, height: Int? = nil) {
    self.type = "image"
    self.url = url
    self.mediaType = mediaType
    self.filename = filename
    self.size = size
    self.width = width
    self.height = height
  }
}

public struct EventPart: Codable, Sendable, Equatable {
  public let type: String
  public let eventType: String
  public let actorUserId: String?
  public let actorAiAgentId: String?
  public let targetUserId: String?
  public let targetAiAgentId: String?
  public let message: String?
}

public struct MetadataPart: Codable, Sendable, Equatable {
  public let type: String
  public let source: String
}

// MARK: - Timeline Responses

public struct TimelineResponse: Codable, Sendable {
  public let items: [TimelineItem]
  public let nextCursor: String?
  public let hasNextPage: Bool
}

public struct SendMessageRequest: Codable, Sendable {
  public let conversationId: String
  public let item: SendMessageItem
  public let createIfPending: Bool?

  public init(conversationId: String, text: String, visitorId: String? = nil) {
    self.conversationId = conversationId
    self.item = SendMessageItem(
      text: text,
      parts: [.text(TextPart(text: text))],
      visitorId: visitorId
    )
    self.createIfPending = true
  }

  public init(conversationId: String, text: String, parts: [TimelineItemPart], visitorId: String?) {
    self.conversationId = conversationId
    self.item = SendMessageItem(
      text: text,
      parts: parts,
      visitorId: visitorId
    )
    self.createIfPending = true
  }
}

public struct SendMessageItem: Codable, Sendable {
  public let id: String?
  public let type: TimelineItemType
  public let text: String
  public let parts: [TimelineItemPart]?
  public let visibility: TimelineItemVisibility
  public let visitorId: String?

  public init(
    id: String? = ULID().ulidString,
    type: TimelineItemType = .message,
    text: String,
    parts: [TimelineItemPart]? = nil,
    visibility: TimelineItemVisibility = .public,
    visitorId: String? = nil
  ) {
    self.id = id
    self.type = type
    self.text = text
    self.parts = parts
    self.visibility = visibility
    self.visitorId = visitorId
  }
}

public struct SendMessageResponse: Codable, Sendable {
  public let item: TimelineItem
}

// MARK: - Pending Message (for optimistic updates)

/// A message that has been optimistically added to the timeline but not yet confirmed by the server.
public struct PendingMessage: Sendable, Identifiable {
  public let id: String
  public let conversationId: String
  public let text: String
  public let attachments: [FileAttachment]
  public let createdAt: Date
  public var status: DeliveryStatus

  public enum DeliveryStatus: Sendable {
    case sending
    case sent(serverId: String)
    case failed(String)
  }

  /// Converts to a TimelineItem for display in the timeline.
  public func toTimelineItem(visitorId: String?, organizationId: String) -> TimelineItem {
    TimelineItem(
      id: id,
      conversationId: conversationId,
      organizationId: organizationId,
      visibility: .public,
      type: .message,
      text: text,
      tool: nil,
      parts: [.text(TextPart(text: text))],
      userId: nil,
      aiAgentId: nil,
      visitorId: visitorId,
      createdAt: SupportFormatters.formatISO8601( createdAt),
      deletedAt: nil
    )
  }
}

// MARK: - File Upload

public struct GenerateUploadURLRequest: Codable, Sendable {
  public let contentType: String
  public let websiteId: String
  public let scope: UploadScope
  public let fileName: String?

  public init(contentType: String, websiteId: String, organizationId: String,
              conversationId: String, fileName: String? = nil) {
    self.contentType = contentType
    self.websiteId = websiteId
    self.scope = UploadScope(
      type: "conversation",
      organizationId: organizationId,
      websiteId: websiteId,
      conversationId: conversationId
    )
    self.fileName = fileName
  }
}

public struct UploadScope: Codable, Sendable {
  public let type: String
  public let organizationId: String
  public let websiteId: String
  public let conversationId: String
}

public struct GenerateUploadURLResponse: Codable, Sendable {
  public let uploadUrl: String
  public let publicUrl: String
  public let key: String
  public let bucket: String
  public let expiresAt: String
  public let contentType: String
}

// MARK: - Activity Tracking

public struct VisitorActivityRequest: Codable, Sendable {
  public let sessionId: String
  public let activityType: String

  public init(sessionId: String, activityType: String) {
    self.sessionId = sessionId
    self.activityType = activityType
  }
}

public struct VisitorActivityResponse: Codable, Sendable {
  public let ok: Bool
  public let acceptedAt: String
}
