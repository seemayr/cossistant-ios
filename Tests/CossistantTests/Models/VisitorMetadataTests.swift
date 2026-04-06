import Testing
import Foundation
@testable import Cossistant

@Suite("VisitorMetadata")
struct VisitorMetadataTests {
  @Test("Literal initialization")
  func literalInit() {
    var metadata = VisitorMetadata()
    metadata["plan"] = "premium"
    metadata["mrr"] = 1000
    metadata["isActive"] = true
    metadata["deletedAt"] = .null

    #expect(metadata["plan"] == .string("premium"))
    #expect(metadata["mrr"] == .number(1000))
    #expect(metadata["isActive"] == .bool(true))
    #expect(metadata["deletedAt"] == .null)
  }

  @Test("JSON round-trip")
  func jsonRoundTrip() throws {
    var original = VisitorMetadata()
    original["appVersion"] = "2.1.0"
    original["sessions"] = 42
    original["hasPaid"] = false

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(VisitorMetadata.self, from: data)

    #expect(decoded["appVersion"] == .string("2.1.0"))
    #expect(decoded["sessions"] == .number(42))
    #expect(decoded["hasPaid"] == .bool(false))
  }

  @Test("Decodes from API JSON")
  func decodesFromAPI() throws {
    let json = """
    { "metadata": { "plan": "pro", "seats": 5, "trial": true, "notes": null } }
    """.data(using: .utf8)!

    let request = try JSONDecoder().decode(UpdateVisitorMetadataRequest.self, from: json)
    #expect(request.metadata["plan"] == .string("pro"))
    #expect(request.metadata["seats"] == .number(5))
    #expect(request.metadata["trial"] == .bool(true))
    #expect(request.metadata["notes"] == .null)
  }
}
