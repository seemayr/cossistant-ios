#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Collects native device information to send as visitor context.
public struct DeviceInfo: Sendable {
  public let browser: String
  public let browserVersion: String
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
    let bundle = Bundle.main
    let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    let osVer = normalizedOSVersion(from: processInfo)

    #if os(iOS)
    let osName = "iOS"
    let deviceName = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "mobile"
    #elseif os(macOS)
    let osName = "macOS"
    let deviceName = "Mac"
    let deviceType = "desktop"
    #else
    let osName = "unknown"
    let deviceName = "unknown"
    let deviceType = "unknown"
    #endif

    return DeviceInfo(
      browser: "Native App",
      browserVersion: version,
      os: osName,
      osVersion: osVer,
      device: deviceName,
      deviceType: deviceType,
      language: Locale.preferredLanguages.first ?? Locale.current.identifier,
      timezone: TimeZone.current.identifier,
      appVersion: version,
      appBuild: build
    )
  }

  public func toVisitorContextRequest() -> UpdateVisitorContextRequest {
    UpdateVisitorContextRequest(
      browser: browser,
      browserVersion: browserVersion,
      os: os,
      osVersion: osVersion,
      device: device,
      deviceType: deviceType,
      language: language,
      timezone: timezone
    )
  }

  /// Converts to metadata suitable for the identify/update visitor API.
  public func toMetadata() -> VisitorMetadata {
    var metadata = VisitorMetadata()
    metadata["browser"] = .string(browser)
    metadata["browserVersion"] = .string(browserVersion)
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

  private static func normalizedOSVersion(from processInfo: ProcessInfo) -> String {
    let version = processInfo.operatingSystemVersion
    if version.patchVersion > 0 {
      return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    return "\(version.majorVersion).\(version.minorVersion)"
  }
}
