import Testing
import Foundation
@testable import Cossistant

@Suite("DeviceInfo")
struct DeviceInfoTests {
  @Test("current() returns non-empty values")
  func currentReturnsValues() {
    let info = DeviceInfo.current()
    #expect(!info.os.isEmpty)
    #expect(!info.osVersion.isEmpty)
    #expect(!info.device.isEmpty)
    #expect(!info.deviceType.isEmpty)
    #expect(!info.language.isEmpty)
    #expect(!info.timezone.isEmpty)
    // appVersion/appBuild may be "unknown" in test runner, that's fine
  }

  @Test("toMetadata() produces correct keys")
  func toMetadataKeys() {
    let info = DeviceInfo.current()
    let metadata = info.toMetadata()

    #expect(metadata["os"] != nil)
    #expect(metadata["osVersion"] != nil)
    #expect(metadata["device"] != nil)
    #expect(metadata["deviceType"] != nil)
    #expect(metadata["language"] != nil)
    #expect(metadata["timezone"] != nil)
    #expect(metadata["appVersion"] != nil)
    #expect(metadata["appBuild"] != nil)
  }

  @Test("toMetadata() includes raw model identifier when available")
  func toMetadataIncludesModelIdentifier() {
    let info = DeviceInfo(
      browser: "Native App",
      browserVersion: "1.0",
      os: "iOS",
      osVersion: "18.0",
      device: "iPhone 13 Pro",
      deviceType: "mobile",
      deviceModelIdentifier: "iPhone14,2",
      language: "en-US",
      timezone: "UTC",
      appVersion: "1.0",
      appBuild: "1"
    )

    let metadata = info.toMetadata()

    #expect(metadata["deviceModelIdentifier"] == .string("iPhone14,2"))
  }

  @Test("known Apple model identifiers resolve to friendly names")
  func resolvesKnownAppleModelIdentifiers() {
    #expect(
      DeviceInfo.deviceName(
        forModelIdentifier: "iPhone14,2",
        fallback: "iPhone"
      ) == "iPhone 13 Pro"
    )
    #expect(
      DeviceInfo.deviceName(
        forModelIdentifier: "iPad16,6",
        fallback: "iPad"
      ) == "iPad Pro 13-inch (M4)"
    )
  }

  @Test("unknown Apple model identifiers fall back to the raw identifier")
  func unknownAppleModelIdentifierFallsBackToRawIdentifier() {
    #expect(
      DeviceInfo.deviceName(
        forModelIdentifier: "iPhone99,9",
        fallback: "iPhone"
      ) == "iPhone99,9"
    )
    #expect(
      DeviceInfo.deviceName(
        forModelIdentifier: nil,
        fallback: "iPhone"
      ) == "iPhone"
    )
  }

  @Test("toMetadata() values are strings")
  func toMetadataValuesAreStrings() {
    let info = DeviceInfo.current()
    let metadata = info.toMetadata()
    for (_, value) in metadata.storage {
      if case .string = value {
        // ok
      } else {
        Issue.record("Expected string value, got \(value)")
      }
    }
  }

  #if os(macOS)
  @Test("macOS reports correct OS and device type")
  func macOSValues() {
    let info = DeviceInfo.current()
    #expect(info.os == "macOS")
    #expect(info.deviceType == "desktop")
    #expect(info.device == "Mac")
  }
  #endif
}
