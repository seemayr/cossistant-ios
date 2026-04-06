import Foundation

/// HTTP client for the Cossistant REST API.
/// Handles authentication headers, JSON encoding/decoding, and error mapping.
actor RESTClient {
  private let configuration: Configuration
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private var visitorId: String?

  init(configuration: Configuration, session: URLSession = .shared) {
    self.configuration = configuration
    self.session = session
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
  }

  func setVisitorId(_ id: String) {
    self.visitorId = id
  }

  // MARK: - Request Execution

  func request<T: Decodable & Sendable>(
    _ endpoint: Endpoint
  ) async throws -> T {
    let urlRequest = try buildRequest(endpoint, body: nil as Data?)
    let (data, response) = try await execute(urlRequest)
    try validateResponse(response, data: data, endpoint: endpoint.path)
    return try decode(data, endpoint: endpoint.path)
  }

  func request<T: Decodable & Sendable, B: Encodable & Sendable>(
    _ endpoint: Endpoint,
    body: B
  ) async throws -> T {
    let bodyData = try encoder.encode(body)
    let urlRequest = try buildRequest(endpoint, body: bodyData)
    let (data, response) = try await execute(urlRequest)
    try validateResponse(response, data: data, endpoint: endpoint.path)
    return try decode(data, endpoint: endpoint.path)
  }

  func requestVoid(
    _ endpoint: Endpoint
  ) async throws {
    let urlRequest = try buildRequest(endpoint, body: nil as Data?)
    let (data, response) = try await execute(urlRequest)
    try validateResponse(response, data: data, endpoint: endpoint.path)
  }

  func requestVoid<B: Encodable & Sendable>(
    _ endpoint: Endpoint,
    body: B
  ) async throws {
    let bodyData = try encoder.encode(body)
    let urlRequest = try buildRequest(endpoint, body: bodyData)
    let (data, response) = try await execute(urlRequest)
    try validateResponse(response, data: data, endpoint: endpoint.path)
  }

  // MARK: - Private Helpers

  private func buildRequest(
    _ endpoint: Endpoint,
    body: Data?
  ) throws -> URLRequest {
    var components = URLComponents(
      url: configuration.apiBaseURL.appendingPathComponent(endpoint.path),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = endpoint.queryItems

    var request = URLRequest(url: components.url!)
    request.httpMethod = endpoint.method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Public-Key")

    if let visitorId {
      request.setValue(visitorId, forHTTPHeaderField: "X-Visitor-Id")
    }

    request.httpBody = body
    return request
  }

  private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
    do {
      return try await session.data(for: request)
    } catch {
      throw CossistantError.networkError(underlying: error)
    }
  }

  private func validateResponse(
    _ response: URLResponse,
    data: Data,
    endpoint: String
  ) throws {
    guard let httpResponse = response as? HTTPURLResponse else { return }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw CossistantError.httpError(
        statusCode: httpResponse.statusCode,
        body: data
      )
    }
  }

  private func decode<T: Decodable>(_ data: Data, endpoint: String) throws -> T {
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw CossistantError.decodingError(underlying: error, endpoint: endpoint)
    }
  }
}
