#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Collects native device information to send as visitor context.
public struct DeviceInfo: Sendable {
  public let os: String
  public let osVersion: String
  public let device: String
  public let deviceType: String
  public let language: String
  public let timezone: String
  public let appVersion: String
  public let appBuild: String

  /// Collects device info from the current environment.
  public static func current() -> DeviceInfo {
    let processInfo = ProcessInfo.processInfo

    #if os(iOS)
    let osName = "iOS"
    let osVer = processInfo.operatingSystemVersionString
    let deviceName = deviceModelName()
    let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "mobile"
    #elseif os(macOS)
    let osName = "macOS"
    let osVer = processInfo.operatingSystemVersionString
    let deviceName = "Mac"
    let deviceType = "desktop"
    #else
    let osName = "unknown"
    let osVer = processInfo.operatingSystemVersionString
    let deviceName = "unknown"
    let deviceType = "unknown"
    #endif

    let bundle = Bundle.main
    let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

    return DeviceInfo(
      os: osName,
      osVersion: osVer,
      device: deviceName,
      deviceType: deviceType,
      language: Locale.current.language.languageCode?.identifier ?? "en",
      timezone: TimeZone.current.identifier,
      appVersion: version,
      appBuild: build
    )
  }

  /// Converts to metadata suitable for the identify/update visitor API.
  public func toMetadata() -> VisitorMetadata {
    var metadata = VisitorMetadata()
    metadata["os"] = .string(os)
    metadata["osVersion"] = .string(osVersion)
    metadata["device"] = .string(device)
    metadata["deviceType"] = .string(deviceType)
    metadata["language"] = .string(language)
    metadata["timezone"] = .string(timezone)
    metadata["appVersion"] = .string(appVersion)
    metadata["appBuild"] = .string(appBuild)
    return metadata
  }

  #if os(iOS)
  private static func deviceModelName() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce("") { id, element in
      guard let value = element.value as? Int8, value != 0 else { return id }
      return id + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
  }
  #endif
}
