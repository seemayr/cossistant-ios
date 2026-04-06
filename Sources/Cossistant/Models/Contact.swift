import Foundation

// MARK: - Identify Contact

public struct IdentifyContactRequest: Codable, Sendable {
  public let visitorId: String?
  public let externalId: String?
  public let name: String?
  public let email: String?
  public let image: String?
  public let metadata: VisitorMetadata?
  public let contactOrganizationId: String?

  public init(
    visitorId: String? = nil,
    externalId: String? = nil,
    name: String? = nil,
    email: String? = nil,
    image: String? = nil,
    metadata: VisitorMetadata? = nil,
    contactOrganizationId: String? = nil
  ) {
    self.visitorId = visitorId
    self.externalId = externalId
    self.name = name
    self.email = email
    self.image = image
    self.metadata = metadata
    self.contactOrganizationId = contactOrganizationId
  }
}

public struct IdentifyContactResponse: Codable, Sendable {
  public let contact: Contact
  public let visitorId: String
}

// MARK: - Contact

public struct Contact: Codable, Sendable, Identifiable {
  public let id: String
  public let externalId: String?
  public let name: String?
  public let email: String?
  public let image: String?
  public let metadata: VisitorMetadata?
  public let contactOrganizationId: String?
  public let websiteId: String
  public let organizationId: String
  public let createdAt: String
  public let updatedAt: String
}
