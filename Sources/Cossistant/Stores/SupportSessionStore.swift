import Foundation
import Observation

@MainActor
@Observable
public final class SupportSessionStore {
  public let context: SupportContext?

  public private(set) var issues: [SupportPreparationIssue] = []
  public private(set) var isPreparing = false

  private var contactPreparationTask: Task<SupportPreparationReport, Never>?
  private var hasCompletedContactPreparation = false

  public init(context: SupportContext? = nil) {
    self.context = context
  }

  public var bannerIssue: SupportPreparationIssue? {
    issues.first(where: { $0.step == .identification })
      ?? issues.first(where: { $0.step == .conversationContext })
      ?? issues.first
  }

  public func prepareOnOpen(using client: CossistantClient) {
    startContactPreparation(using: client, force: false)
  }

  public func prepareForNewConversation(using client: CossistantClient) async {
    await awaitContactPreparation(using: client, force: false)
    await attachConversationContext(using: client)
  }

  public func retry(using client: CossistantClient, includeConversationContext: Bool) async {
    await awaitContactPreparation(using: client, force: true)
    if includeConversationContext {
      await attachConversationContext(using: client)
    }
  }

  private func startContactPreparation(using client: CossistantClient, force: Bool) {
    guard let context else { return }

    let needsContactPreparation = context.identity != nil || !context.contactMetadata.storage.isEmpty
    guard needsContactPreparation else { return }

    if force {
      replaceIssues(for: [.identification, .contactMetadata], with: [])
      contactPreparationTask = nil
      hasCompletedContactPreparation = false
    }

    guard !hasCompletedContactPreparation else { return }
    guard contactPreparationTask == nil else { return }

    let identity = context.identity
    let contactMetadata = context.contactMetadata

    isPreparing = true
    contactPreparationTask = Task { @MainActor [weak self] in
      guard let self else { return SupportPreparationReport() }

      let report = await client.prepareSupportContact(
        identity: identity,
        metadata: contactMetadata
      )

      self.replaceIssues(for: [.identification, .contactMetadata], with: report.issues)
      self.hasCompletedContactPreparation = true
      self.contactPreparationTask = nil
      self.isPreparing = false

      return report
    }
  }

  private func awaitContactPreparation(using client: CossistantClient, force: Bool) async {
    startContactPreparation(using: client, force: force)
    if let contactPreparationTask {
      _ = await contactPreparationTask.value
    }
  }

  private func attachConversationContext(using client: CossistantClient) async {
    guard let context, !context.conversationContext.storage.isEmpty else { return }

    replaceIssues(for: [.conversationContext], with: [])
    isPreparing = true

    let report = await client.prepareSupportConversationContext(context.conversationContext)
    replaceIssues(for: [.conversationContext], with: report.issues)

    isPreparing = false
  }

  private func replaceIssues(
    for steps: Set<SupportPreparationStep>,
    with replacement: [SupportPreparationIssue]
  ) {
    issues.removeAll { steps.contains($0.step) }
    issues.append(contentsOf: replacement)
  }
}
