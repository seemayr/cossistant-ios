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

  func clearVisitorId() {
    visitorId = nil
  }

  // MARK: - Request Execution

  func request<T: Decodable & Sendable>(
    _ endpoint: Endpoint
  ) async throws -> T {
    SupportLogger.requestStarted(endpoint.method, path: endpoint.path)
    let urlRequest = try buildRequest(endpoint, body: nil as Data?)
    let (data, response) = try await execute(urlRequest, endpoint: endpoint)
    try validateResponse(response, data: data, endpoint: endpoint)
    return try decode(data, endpoint: endpoint)
  }

  func request<T: Decodable & Sendable, B: Encodable & Sendable>(
    _ endpoint: Endpoint,
    body: B
  ) async throws -> T {
    SupportLogger.requestStarted(endpoint.method, path: endpoint.path)
    let bodyData = try encoder.encode(body)
    let urlRequest = try buildRequest(endpoint, body: bodyData)
    let (data, response) = try await execute(urlRequest, endpoint: endpoint)
    try validateResponse(response, data: data, endpoint: endpoint)
    return try decode(data, endpoint: endpoint)
  }

  func requestVoid(
    _ endpoint: Endpoint
  ) async throws {
    SupportLogger.requestStarted(endpoint.method, path: endpoint.path)
    let urlRequest = try buildRequest(endpoint, body: nil as Data?)
    let (data, response) = try await execute(urlRequest, endpoint: endpoint)
    try validateResponse(response, data: data, endpoint: endpoint)
    SupportLogger.requestSuccess(endpoint.method, path: endpoint.path, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
  }

  func requestVoid<B: Encodable & Sendable>(
    _ endpoint: Endpoint,
    body: B
  ) async throws {
    SupportLogger.requestStarted(endpoint.method, path: endpoint.path)
    let bodyData = try encoder.encode(body)
    let urlRequest = try buildRequest(endpoint, body: bodyData)
    let (data, response) = try await execute(urlRequest, endpoint: endpoint)
    try validateResponse(response, data: data, endpoint: endpoint)
    SupportLogger.requestSuccess(endpoint.method, path: endpoint.path, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
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
    request.setValue(configuration.origin, forHTTPHeaderField: "Origin")

    if let visitorId {
      request.setValue(visitorId, forHTTPHeaderField: "X-Visitor-Id")
    }

    request.httpBody = body
    return request
  }

  private func execute(_ request: URLRequest, endpoint: Endpoint) async throws -> (Data, URLResponse) {
    do {
      return try await session.data(for: request)
    } catch {
      SupportLogger.requestFailed(endpoint.method, path: endpoint.path, error: error)
      throw CossistantError.networkError(underlying: error)
    }
  }

  private func validateResponse(
    _ response: URLResponse,
    data: Data,
    endpoint: Endpoint
  ) throws {
    guard let httpResponse = response as? HTTPURLResponse else { return }
    let status = httpResponse.statusCode
    guard (200...299).contains(status) else {
      SupportLogger.requestHTTPError(endpoint.method, path: endpoint.path, status: status, body: data)
      throw CossistantError.httpError(statusCode: status, body: data)
    }
    SupportLogger.requestSuccess(endpoint.method, path: endpoint.path, status: status)
  }

  private func decode<T: Decodable>(_ data: Data, endpoint: Endpoint) throws -> T {
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      SupportLogger.decodingError(endpoint.path, error: error)
      throw CossistantError.decodingError(underlying: error, endpoint: endpoint.path)
    }
  }
}
