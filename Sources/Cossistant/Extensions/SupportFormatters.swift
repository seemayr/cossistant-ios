import Foundation

/// Shared formatters and parsers — avoids creating expensive instances in view bodies.
enum SupportFormatters {

  // MARK: - ISO 8601 Parsing

  /// Primary strategy: ISO 8601 with fractional seconds (handles 1-9 fractional digits).
  private static let iso8601WithFractional: Date.ISO8601FormatStyle = .iso8601
    .year().month().day()
    .timeZone(separator: .colon)
    .time(includingFractionalSeconds: true)
    .timeSeparator(.colon)
    .dateSeparator(.dash)

  /// Fallback strategy: ISO 8601 without fractional seconds.
  private static let iso8601WithoutFractional: Date.ISO8601FormatStyle = .iso8601
    .year().month().day()
    .timeZone(separator: .colon)
    .time(includingFractionalSeconds: false)
    .timeSeparator(.colon)
    .dateSeparator(.dash)

  /// Parses an ISO 8601 date string with variable-length fractional seconds.
  ///
  /// The API returns timestamps with 0, 2, or 3 fractional-second digits.
  /// `Date.ISO8601FormatStyle` with fractional seconds handles 1-9 digits natively,
  /// but requires a fallback for strings with no fractional part at all.
  static func parseISO8601(_ string: String) -> Date? {
    if let date = try? iso8601WithFractional.parse(string) { return date }
    return try? iso8601WithoutFractional.parse(string)
  }

  /// Formats a `Date` to ISO 8601 with millisecond precision (for API requests).
  static func formatISO8601(_ date: Date) -> String {
    iso8601WithFractional.format(date)
  }

  // MARK: - Display Formatters

  /// Short time display (e.g. "2:30 PM").
  static let timeOnly: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
  }()

  /// Relative date display (e.g. "2h ago").
  nonisolated(unsafe) static let relativeDate: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f
  }()
}
