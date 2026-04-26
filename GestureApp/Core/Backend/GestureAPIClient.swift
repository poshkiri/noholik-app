import Foundation

// MARK: - APIError

enum APIError: Error, LocalizedError {
    case noToken
    case badStatus(Int, message: String?)
    case decoding(Error)
    case network(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .noToken:                       return "Требуется авторизация"
        case .badStatus(let c, let m):       return m ?? "Ошибка сервера: \(c)"
        case .decoding(let e):               return "Ошибка ответа: \(e.localizedDescription)"
        case .network(let e):                return "Нет соединения: \(e.localizedDescription)"
        case .unauthorized:                  return "Сессия истекла, войдите снова"
        }
    }
}

extension Notification.Name {
    /// Posted by `GestureAPIClient` whenever the server returns HTTP 401.
    /// `AppState` observes this to sign the user out automatically.
    static let sessionExpired = Notification.Name("GestureApp.sessionExpired")
}

// MARK: - GestureAPIClient

/// Thread-safe URL session wrapper.
///
/// Reads the JWT from `KeychainStore` before every request, so a fresh token
/// is picked up automatically after sign-in without having to restart the client.
final class GestureAPIClient: @unchecked Sendable {

    static let shared = GestureAPIClient()

    let keychain: KeychainStore
    private let base: URL
    private let session: URLSession

    /// Called when any API request receives HTTP 401.
    /// Should attempt to silently get a new JWT and return `true` on success.
    /// When `nil` or returns `false`, the `.sessionExpired` notification is posted.
    var tokenRefreshHandler: (() async -> Bool)?

    // Decoders / encoders are stateless value types, safe to share.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // DTOs define their own CodingKeys; do NOT use convertFromSnakeCase to
        // avoid conflicts with explicit raw-value keys like `case userA = "user_a"`.
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(base: URL = APIConfig.baseURL,
         session: URLSession? = nil,
         keychain: KeychainStore = .shared) {
        self.base = base
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 20
            cfg.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: cfg)
        }
        self.keychain = keychain
    }

    // MARK: - Typed convenience

    func get<T: Decodable>(path: String) async throws -> T {
        let req = try buildRequestNoBody("GET", path: path)
        return try await perform(req)
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let req = try buildRequest("POST", path: path, body: body)
        return try await perform(req)
    }

    func put<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let req = try buildRequest("PUT", path: path, body: body)
        return try await perform(req)
    }

    /// Fire-and-forget variant with body.
    func send<B: Encodable>(_ method: String, path: String, body: B) async throws {
        let req = try buildRequest(method, path: path, body: body)
        try await execute(req)
    }

    /// Fire-and-forget variant without body.
    func send(_ method: String, path: String) async throws {
        let req = try buildRequestNoBody(method, path: path)
        try await execute(req)
    }

    // MARK: - Multipart upload

    func upload<T: Decodable>(path: String,
                              fileData: Data,
                              mimeType: String,
                              fieldName: String) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let uploadURL = URL(string: base.absoluteString + path) else {
            throw APIError.network(URLError(.badURL))
        }
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")
        if let token = keychain.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = buildMultipart(data: fileData,
                                      mimeType: mimeType,
                                      fieldName: fieldName,
                                      boundary: boundary)
        return try await perform(req)
    }

    // MARK: - Internal helpers (used by token-refresh code)

    /// Builds a JSON request WITHOUT an Authorization header.
    /// Used for public endpoints such as `POST /auth/vk`.
    func buildPublicRequest<B: Encodable>(_ method: String, path: String, body: B) throws -> URLRequest {
        guard let url = URL(string: base.absoluteString + path) else {
            throw APIError.network(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        return req
    }

    // MARK: - Private helpers

    private func buildRequestNoBody(_ method: String, path: String) throws -> URLRequest {
        guard let url = URL(string: base.absoluteString + path) else {
            throw APIError.network(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = keychain.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func buildRequest<B: Encodable>(_ method: String, path: String, body: B?) throws -> URLRequest {
        guard let url = URL(string: base.absoluteString + path) else {
            throw APIError.network(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = keychain.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    @discardableResult
    private func execute(_ req: URLRequest, allowRetry: Bool = true) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            if allowRetry, let refresh = tokenRefreshHandler, await refresh() {
                // Token refreshed — rebuild the request with the new JWT and retry once.
                var retried = req
                if let token = keychain.token {
                    retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                return try await execute(retried, allowRetry: false)
            }
            throw APIError.unauthorized
        default:
            let message = (try? JSONDecoder().decode(ServerErrorBody.self, from: data))?.error
            throw APIError.badStatus(http.statusCode, message: message)
        }
    }

    /// Direct HTTP call that bypasses retry / refresh logic.
    /// Used internally by the token refresh flow to avoid infinite recursion.
    func executeDirectly<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data = try await execute(req, allowRetry: false)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data = try await execute(req)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func buildMultipart(data: Data,
                                mimeType: String,
                                fieldName: String,
                                boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"
        body += "--\(boundary)\(crlf)".utf8Data
        body += "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"upload\"\(crlf)".utf8Data
        body += "Content-Type: \(mimeType)\(crlf)\(crlf)".utf8Data
        body += data
        body += "\(crlf)--\(boundary)--\(crlf)".utf8Data
        return body
    }
}

// MARK: - Internal types

private struct ServerErrorBody: Decodable { let error: String }

private extension String {
    var utf8Data: Data { Data(utf8) }
}

private func += (lhs: inout Data, rhs: Data) { lhs.append(rhs) }
