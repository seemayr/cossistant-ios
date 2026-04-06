import Foundation

// MARK: - Public Website Response (from GET /websites)

public struct PublicWebsiteResponse: Codable, Sendable {
  public let id: String
  public let name: String
  public let domain: String
  public let description: String?
  public let logoUrl: String?
  public let organizationId: String
  public let status: String
  public let lastOnlineAt: String?
  public let availableHumanAgents: [HumanAgent]
  public let availableAIAgents: [AIAgent]
  public let visitor: PublicVisitor
}

public struct HumanAgent: Codable, Sendable {
  public let id: String
  public let name: String?
  public let image: String?
  public let lastSeenAt: String?
}

public struct AIAgent: Codable, Sendable {
  public let id: String
  public let name: String
  public let image: String?
}

public struct PublicVisitor: Codable, Sendable {
  public let id: String
  public let isBlocked: Bool
  public let language: String?
  public let contact: PublicContact?
}

public struct PublicContact: Codable, Sendable {
  public let id: String
  public let name: String?
  public let email: String?
  public let image: String?
  public let metadataHash: String?
}
