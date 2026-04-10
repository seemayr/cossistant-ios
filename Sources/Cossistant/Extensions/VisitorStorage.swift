import Foundation

/// Thread-safe visitor ID persistence via UserDefaults.
struct VisitorStorage: Sendable {
  private nonisolated(unsafe) let defaults: UserDefaults
  private let key: String

  init(
    defaults: UserDefaults = .standard,
    websiteId: String = "default"
  ) {
    self.defaults = defaults
    self.key = "cossistant:visitor:\(websiteId)"
  }

  var visitorId: String? {
    get { defaults.string(forKey: key) }
    nonmutating set { defaults.set(newValue, forKey: key) }
  }
}
