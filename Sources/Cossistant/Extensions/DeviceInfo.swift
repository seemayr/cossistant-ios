#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
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
  public let deviceModelIdentifier: String?
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
    let genericDeviceName = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    let modelIdentifier = currentAppleModelIdentifier()
    let deviceName = deviceName(forModelIdentifier: modelIdentifier, fallback: genericDeviceName)
    let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "mobile"
    #elseif os(macOS)
    let osName = "macOS"
    let deviceName = "Mac"
    let modelIdentifier: String? = nil
    let deviceType = "desktop"
    #else
    let osName = "unknown"
    let deviceName = "unknown"
    let modelIdentifier: String? = nil
    let deviceType = "unknown"
    #endif

    return DeviceInfo(
      browser: "Native App",
      browserVersion: version,
      os: osName,
      osVersion: osVer,
      device: deviceName,
      deviceType: deviceType,
      deviceModelIdentifier: modelIdentifier,
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
    if let deviceModelIdentifier {
      metadata["deviceModelIdentifier"] = .string(deviceModelIdentifier)
    }
    metadata["language"] = .string(language)
    metadata["timezone"] = .string(timezone)
    metadata["appVersion"] = .string(appVersion)
    metadata["appBuild"] = .string(appBuild)
    return metadata
  }

  static func deviceName(forModelIdentifier identifier: String?, fallback: String) -> String {
    guard let identifier, !identifier.isEmpty else { return fallback }
    return appleDeviceNamesByIdentifier[identifier] ?? identifier
  }

  private static func currentAppleModelIdentifier() -> String? {
    #if targetEnvironment(simulator)
    if let simulatorIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
       !simulatorIdentifier.isEmpty {
      return simulatorIdentifier
    }
    #endif

    return hardwareModelIdentifier()
  }

  private static func hardwareModelIdentifier() -> String? {
    #if canImport(Darwin)
    var systemInfo = utsname()
    guard uname(&systemInfo) == 0 else { return nil }
    let machineCapacity = MemoryLayout.size(ofValue: systemInfo.machine)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: machineCapacity) {
        String(cString: $0)
      }
    }
    #else
    return nil
    #endif
  }

  private static func normalizedOSVersion(from processInfo: ProcessInfo) -> String {
    let version = processInfo.operatingSystemVersion
    if version.patchVersion > 0 {
      return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    return "\(version.majorVersion).\(version.minorVersion)"
  }

  /// Known iOS-family model identifiers. Unknown future identifiers are sent raw.
  private static let appleDeviceNamesByIdentifier: [String: String] = [
    "iPhone1,1": "iPhone",
    "iPhone1,2": "iPhone 3G",
    "iPhone2,1": "iPhone 3GS",
    "iPhone3,1": "iPhone 4",
    "iPhone3,2": "iPhone 4",
    "iPhone3,3": "iPhone 4",
    "iPhone4,1": "iPhone 4S",
    "iPhone4,2": "iPhone 4S",
    "iPhone4,3": "iPhone 4S",
    "iPhone5,1": "iPhone 5",
    "iPhone5,2": "iPhone 5",
    "iPhone5,3": "iPhone 5C",
    "iPhone5,4": "iPhone 5C",
    "iPhone6,1": "iPhone 5S",
    "iPhone6,2": "iPhone 5S",
    "iPhone7,2": "iPhone 6",
    "iPhone7,1": "iPhone 6 Plus",
    "iPhone8,1": "iPhone 6S",
    "iPhone8,2": "iPhone 6S Plus",
    "iPhone8,4": "iPhone SE",
    "iPhone9,1": "iPhone 7",
    "iPhone9,3": "iPhone 7",
    "iPhone9,2": "iPhone 7 Plus",
    "iPhone9,4": "iPhone 7 Plus",
    "iPhone10,1": "iPhone 8",
    "iPhone10,4": "iPhone 8",
    "iPhone10,2": "iPhone 8 Plus",
    "iPhone10,5": "iPhone 8 Plus",
    "iPhone10,3": "iPhone X",
    "iPhone10,6": "iPhone X",
    "iPhone11,2": "iPhone XS",
    "iPhone11,4": "iPhone XS Max",
    "iPhone11,6": "iPhone XS Max",
    "iPhone11,8": "iPhone XR",
    "iPhone12,1": "iPhone 11",
    "iPhone12,3": "iPhone 11 Pro",
    "iPhone12,5": "iPhone 11 Pro Max",
    "iPhone12,8": "iPhone SE 2",
    "iPhone13,1": "iPhone 12 mini",
    "iPhone13,2": "iPhone 12",
    "iPhone13,3": "iPhone 12 Pro",
    "iPhone13,4": "iPhone 12 Pro Max",
    "iPhone14,4": "iPhone 13 mini",
    "iPhone14,5": "iPhone 13",
    "iPhone14,2": "iPhone 13 Pro",
    "iPhone14,3": "iPhone 13 Pro Max",
    "iPhone14,6": "iPhone SE 3",
    "iPhone14,7": "iPhone 14",
    "iPhone14,8": "iPhone 14 Plus",
    "iPhone15,2": "iPhone 14 Pro",
    "iPhone15,3": "iPhone 14 Pro Max",
    "iPhone15,4": "iPhone 15",
    "iPhone15,5": "iPhone 15 Plus",
    "iPhone16,1": "iPhone 15 Pro",
    "iPhone16,2": "iPhone 15 Pro Max",
    "iPhone17,3": "iPhone 16",
    "iPhone17,4": "iPhone 16 Plus",
    "iPhone17,1": "iPhone 16 Pro",
    "iPhone17,2": "iPhone 16 Pro Max",
    "iPhone17,5": "iPhone 16e",
    "iPhone18,1": "iPhone 17 Pro",
    "iPhone18,2": "iPhone 17 Pro Max",
    "iPhone18,3": "iPhone 17",
    "iPhone18,4": "iPhone Air",

    "iPad1,1": "iPad",
    "iPad2,1": "iPad 2",
    "iPad2,2": "iPad 2",
    "iPad2,3": "iPad 2",
    "iPad2,4": "iPad 2",
    "iPad3,1": "iPad 3",
    "iPad3,2": "iPad 3",
    "iPad3,3": "iPad 3",
    "iPad3,4": "iPad 4",
    "iPad3,5": "iPad 4",
    "iPad3,6": "iPad 4",
    "iPad6,11": "iPad 5",
    "iPad6,12": "iPad 5",
    "iPad7,5": "iPad 6",
    "iPad7,6": "iPad 6",
    "iPad7,11": "iPad 7",
    "iPad7,12": "iPad 7",
    "iPad11,6": "iPad 8",
    "iPad11,7": "iPad 8",
    "iPad12,1": "iPad 9",
    "iPad12,2": "iPad 9",
    "iPad13,18": "iPad 10",
    "iPad13,19": "iPad 10",
    "iPad15,7": "iPad (A16)",
    "iPad15,8": "iPad (A16)",
    "iPad4,1": "iPad Air",
    "iPad4,2": "iPad Air",
    "iPad4,3": "iPad Air",
    "iPad5,3": "iPad Air 2",
    "iPad5,4": "iPad Air 2",
    "iPad11,3": "iPad Air 3",
    "iPad11,4": "iPad Air 3",
    "iPad13,1": "iPad Air 4",
    "iPad13,2": "iPad Air 4",
    "iPad13,16": "iPad Air 5",
    "iPad13,17": "iPad Air 5",
    "iPad14,8": "iPad Air 11-inch (M2)",
    "iPad14,9": "iPad Air 11-inch (M2)",
    "iPad15,3": "iPad Air 11-inch (M3)",
    "iPad15,4": "iPad Air 11-inch (M3)",
    "iPad14,10": "iPad Air 13-inch (M2)",
    "iPad14,11": "iPad Air 13-inch (M2)",
    "iPad15,5": "iPad Air 13-inch (M3)",
    "iPad15,6": "iPad Air 13-inch (M3)",
    "iPad2,5": "iPad Mini",
    "iPad2,6": "iPad Mini",
    "iPad2,7": "iPad Mini",
    "iPad4,4": "iPad Mini 2",
    "iPad4,5": "iPad Mini 2",
    "iPad4,6": "iPad Mini 2",
    "iPad4,7": "iPad Mini 3",
    "iPad4,8": "iPad Mini 3",
    "iPad4,9": "iPad Mini 3",
    "iPad5,1": "iPad Mini 4",
    "iPad5,2": "iPad Mini 4",
    "iPad11,1": "iPad Mini 5",
    "iPad11,2": "iPad Mini 5",
    "iPad14,1": "iPad Mini 6",
    "iPad14,2": "iPad Mini 6",
    "iPad16,1": "iPad Mini (A17 Pro)",
    "iPad16,2": "iPad Mini (A17 Pro)",
    "iPad6,3": "iPad Pro 9.7-inch",
    "iPad6,4": "iPad Pro 9.7-inch",
    "iPad7,3": "iPad Pro 10.5-inch",
    "iPad7,4": "iPad Pro 10.5-inch",
    "iPad8,1": "iPad Pro 11-inch",
    "iPad8,2": "iPad Pro 11-inch",
    "iPad8,3": "iPad Pro 11-inch",
    "iPad8,4": "iPad Pro 11-inch",
    "iPad8,9": "iPad Pro 11-inch 2",
    "iPad8,10": "iPad Pro 11-inch 2",
    "iPad13,4": "iPad Pro 11-inch 3",
    "iPad13,5": "iPad Pro 11-inch 3",
    "iPad13,6": "iPad Pro 11-inch 3",
    "iPad13,7": "iPad Pro 11-inch 3",
    "iPad14,3": "iPad Pro 11-inch (M2)",
    "iPad14,4": "iPad Pro 11-inch (M2)",
    "iPad16,3": "iPad Pro 11-inch (M4)",
    "iPad16,4": "iPad Pro 11-inch (M4)",
    "iPad17,1": "iPad Pro 11-inch (M5)",
    "iPad17,2": "iPad Pro 11-inch (M5)",
    "iPad6,7": "iPad Pro 12.9-inch",
    "iPad6,8": "iPad Pro 12.9-inch",
    "iPad7,1": "iPad Pro 12.9-inch 2",
    "iPad7,2": "iPad Pro 12.9-inch 2",
    "iPad8,5": "iPad Pro 12.9-inch 3",
    "iPad8,6": "iPad Pro 12.9-inch 3",
    "iPad8,7": "iPad Pro 12.9-inch 3",
    "iPad8,8": "iPad Pro 12.9-inch 3",
    "iPad8,11": "iPad Pro 12.9-inch 4",
    "iPad8,12": "iPad Pro 12.9-inch 4",
    "iPad13,8": "iPad Pro 12.9-inch 5",
    "iPad13,9": "iPad Pro 12.9-inch 5",
    "iPad13,10": "iPad Pro 12.9-inch 5",
    "iPad13,11": "iPad Pro 12.9-inch 5",
    "iPad14,5": "iPad Pro 12.9-inch (M2)",
    "iPad14,6": "iPad Pro 12.9-inch (M2)",
    "iPad16,5": "iPad Pro 13-inch (M4)",
    "iPad16,6": "iPad Pro 13-inch (M4)",
    "iPad17,3": "iPad Pro 13-inch (M5)",
    "iPad17,4": "iPad Pro 13-inch (M5)",

    "iPod1,1": "iPod Touch",
    "iPod2,1": "iPod Touch 2",
    "iPod3,1": "iPod Touch 3",
    "iPod4,1": "iPod Touch 4",
    "iPod5,1": "iPod Touch 5",
    "iPod7,1": "iPod Touch 6",
    "iPod9,1": "iPod Touch 7",

    "i386": "Simulator",
    "x86_64": "Simulator",
    "arm64": "Simulator",
  ]
}
