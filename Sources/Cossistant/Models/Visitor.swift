import Foundation

/// Free-form metadata: keys are strings, values are string, number, boolean, or null.
/// Encoded as a JSON object with heterogeneous values.
public struct VisitorMetadata: Codable, Sendable {
  public var storage: [String: MetadataValue]

  public init(_ dictionary: [String: MetadataValue] = [:]) {
    self.storage = dictionary
  }

  public subscript(key: String) -> MetadataValue? {
    get { storage[key] }
    set { storage[key] = newValue }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    storage = try container.decode([String: MetadataValue].self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(storage)
  }
}

public enum MetadataValue: Codable, Sendable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else {
      self = .null
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }
}

/// Convenience literal support for metadata values.
extension MetadataValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self = .string(value) }
}

extension MetadataValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension MetadataValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) { self = .number(value) }
}

extension MetadataValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) { self = .bool(value) }
}

// MARK: - Update Visitor Metadata

public struct UpdateVisitorMetadataRequest: Codable, Sendable {
  public let metadata: VisitorMetadata

  public init(metadata: VisitorMetadata) {
    self.metadata = metadata
  }
}
