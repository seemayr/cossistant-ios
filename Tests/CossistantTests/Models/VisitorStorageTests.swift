import Testing
import Foundation
@testable import Cossistant

@Suite("VisitorStorage")
struct VisitorStorageTests {
  @Test("Stores and retrieves visitor ID")
  func storeAndRetrieve() {
    let defaults = UserDefaults(suiteName: "CossistantTest_\(UUID().uuidString)")!
    let storage = VisitorStorage(defaults: defaults, websiteId: "test_site")

    #expect(storage.visitorId == nil)
    storage.visitorId = "vis_12345"
    #expect(storage.visitorId == "vis_12345")
  }

  @Test("Different websiteIds are isolated")
  func isolatedByWebsiteId() {
    let defaults = UserDefaults(suiteName: "CossistantTest_\(UUID().uuidString)")!
    let storageA = VisitorStorage(defaults: defaults, websiteId: "site_a")
    let storageB = VisitorStorage(defaults: defaults, websiteId: "site_b")

    storageA.visitorId = "visitor_a"
    storageB.visitorId = "visitor_b"

    #expect(storageA.visitorId == "visitor_a")
    #expect(storageB.visitorId == "visitor_b")
  }

  @Test("Setting nil clears the stored value")
  func clearVisitorId() {
    let defaults = UserDefaults(suiteName: "CossistantTest_\(UUID().uuidString)")!
    let storage = VisitorStorage(defaults: defaults, websiteId: "test")

    storage.visitorId = "vis_temp"
    #expect(storage.visitorId == "vis_temp")

    storage.visitorId = nil
    #expect(storage.visitorId == nil)
  }
}
