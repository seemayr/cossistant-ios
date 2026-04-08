import Foundation

/// Type-safe API endpoint definitions.
enum Endpoint {
  case getWebsite
  case listConversations(page: Int, limit: Int)
  case getConversation(id: String)
  case createConversation
  case getTimeline(conversationId: String, limit: Int, cursor: String?)
  case sendMessage
  case markSeen(conversationId: String)
  case setTyping(conversationId: String)
  case submitRating(conversationId: String)
  case identifyContact
  case updateVisitorMetadata(visitorId: String)
  case generateUploadURL
  case visitorActivity

  var method: String {
    switch self {
    case .getWebsite, .listConversations, .getConversation, .getTimeline:
      return "GET"
    case .createConversation, .sendMessage, .markSeen, .setTyping, .submitRating, .identifyContact, .generateUploadURL, .visitorActivity:
      return "POST"
    case .updateVisitorMetadata:
      return "PATCH"
    }
  }

  var path: String {
    switch self {
    case .getWebsite:
      return "/websites"
    case .listConversations:
      return "/conversations"
    case .getConversation(let id):
      return "/conversations/\(id)"
    case .createConversation:
      return "/conversations"
    case .getTimeline(let conversationId, _, _):
      return "/conversations/\(conversationId)/timeline"
    case .sendMessage:
      return "/messages"
    case .markSeen(let conversationId):
      return "/conversations/\(conversationId)/seen"
    case .setTyping(let conversationId):
      return "/conversations/\(conversationId)/typing"
    case .submitRating(let conversationId):
      return "/conversations/\(conversationId)/rating"
    case .identifyContact:
      return "/contacts/identify"
    case .updateVisitorMetadata(let visitorId):
      return "/visitors/\(visitorId)/metadata"
    case .generateUploadURL:
      return "/uploads/sign-url"
    case .visitorActivity:
      return "/visitors/activity"
    }
  }

  var queryItems: [URLQueryItem]? {
    switch self {
    case .listConversations(let page, let limit):
      return [
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "orderBy", value: "updatedAt"),
        URLQueryItem(name: "order", value: "desc"),
      ]
    case .getTimeline(_, let limit, let cursor):
      var items = [URLQueryItem(name: "limit", value: "\(limit)")]
      if let cursor {
        items.append(URLQueryItem(name: "cursor", value: cursor))
      }
      return items
    default:
      return nil
    }
  }
}
