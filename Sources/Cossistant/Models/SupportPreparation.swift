import Foundation

public enum SupportPreparationStep: String, Sendable, Equatable, Hashable {
  case identification
  case contactMetadata
  case conversationContext
}

public struct SupportPreparationIssue: Error, Sendable, Equatable, Hashable, Identifiable {
  public var id: SupportPreparationStep { step }

  public let step: SupportPreparationStep
  public let technicalDetails: String

  public init(step: SupportPreparationStep, technicalDetails: String) {
    self.step = step
    self.technicalDetails = technicalDetails
  }

  public var title: String {
    CossistantContent.current.supportPreparationWarningTitle
      ?? "Details unavailable"
  }

  public var message: String {
    switch step {
    case .identification:
      return CossistantContent.current.supportPreparationIdentificationMessage
        ?? "You can still contact support, but we couldn't attach your account details right now."
    case .contactMetadata:
      return CossistantContent.current.supportPreparationDetailsMessage
        ?? "You can still contact support, but some support details may be missing."
    case .conversationContext:
      return CossistantContent.current.supportPreparationDetailsMessage
        ?? "You can still contact support, but some support details may be missing."
    }
  }
}

public struct SupportPreparationReport: Sendable, Equatable, Hashable {
  public let issues: [SupportPreparationIssue]

  public init(issues: [SupportPreparationIssue] = []) {
    self.issues = issues
  }

  public var isDegraded: Bool {
    !issues.isEmpty
  }
}
