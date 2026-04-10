import Testing
import Foundation
@testable import Cossistant

@Suite("SupportSessionStore")
struct SupportSessionStoreTests {

  // MARK: - bannerIssue

  @Test("bannerIssue returns nil when no issues")
  @MainActor
  func bannerIssueNilWhenEmpty() {
    let store = SupportSessionStore()
    #expect(store.bannerIssue == nil)
  }

  @Test("bannerIssue prioritizes identification over contactMetadata")
  @MainActor
  func bannerIssuePrioritizesIdentification() {
    let store = SupportSessionStore()
    let metadataIssue = SupportPreparationIssue(
      step: .contactMetadata,
      technicalDetails: "metadata failed"
    )
    let identIssue = SupportPreparationIssue(
      step: .identification,
      technicalDetails: "identify failed"
    )
    // Add metadata issue first, then identification
    store.issues = [metadataIssue, identIssue]
    #expect(store.bannerIssue?.step == .identification)
  }

  @Test("bannerIssue falls back to contactMetadata when no identification issue")
  @MainActor
  func bannerIssueFallsBack() {
    let store = SupportSessionStore()
    let issue = SupportPreparationIssue(
      step: .contactMetadata,
      technicalDetails: "metadata failed"
    )
    store.issues = [issue]
    #expect(store.bannerIssue?.step == .contactMetadata)
  }

  // MARK: - dismiss

  @Test("dismiss hides the issue from bannerIssue")
  @MainActor
  func dismissHidesIssue() {
    let store = SupportSessionStore()
    let issue = SupportPreparationIssue(
      step: .identification,
      technicalDetails: "identify failed"
    )
    store.issues = [issue]
    #expect(store.bannerIssue != nil)

    store.dismiss(issue)
    #expect(store.bannerIssue == nil)
  }

  @Test("dismiss one step still shows other step")
  @MainActor
  func dismissOneStepShowsOther() {
    let store = SupportSessionStore()
    let identIssue = SupportPreparationIssue(
      step: .identification,
      technicalDetails: "identify failed"
    )
    let metadataIssue = SupportPreparationIssue(
      step: .contactMetadata,
      technicalDetails: "metadata failed"
    )
    store.issues = [identIssue, metadataIssue]
    #expect(store.bannerIssue?.step == .identification)

    store.dismiss(identIssue)
    #expect(store.bannerIssue?.step == .contactMetadata)
  }

  @Test("dismiss all steps returns nil bannerIssue")
  @MainActor
  func dismissAllSteps() {
    let store = SupportSessionStore()
    let identIssue = SupportPreparationIssue(
      step: .identification,
      technicalDetails: "identify failed"
    )
    let metadataIssue = SupportPreparationIssue(
      step: .contactMetadata,
      technicalDetails: "metadata failed"
    )
    store.issues = [identIssue, metadataIssue]

    store.dismiss(identIssue)
    store.dismiss(metadataIssue)
    #expect(store.bannerIssue == nil)
    // Issues still exist, just dismissed
    #expect(store.issues.count == 2)
  }
}
