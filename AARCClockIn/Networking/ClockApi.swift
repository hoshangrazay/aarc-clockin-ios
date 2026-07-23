import Foundation

enum ApiError: LocalizedError {
    case network(String)
    case server(Int)
    case decoding(String)
    case badResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .network(let m): return "Network error: \(m)"
        case .server(let code): return "Server error (\(code))"
        case .decoding(let m): return "Data error: \(m)"
        case .badResponse: return "Unexpected response from server"
        case .api(let m): return m
        }
    }
}

actor ClockApi {
    static let shared = ClockApi()

    private let baseURLString = "https://www.aarcvisitor.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func makeURL(_ path: String, token: String?) -> URL {
        var components = URLComponents(string: baseURLString + path)!
        if let token = token {
            components.queryItems = [URLQueryItem(name: "t", value: token)]
        }
        return components.url!
    }

    private func postRequest(url: URL, body: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        return req
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        let url = makeURL("/api/clock/login", token: nil)
        let body = "username=\(urlEncode(username))&password=\(urlEncode(password))"
        return try await performRequest(postRequest(url: url, body: body))
    }

    func status(token: String) async throws -> StatusResponse {
        let url = makeURL("/api/clock/status", token: token)
        return try await performRequest(URLRequest(url: url))
    }

    func toggle(token: String, lat: Double?, lng: Double?) async throws -> ToggleResponse {
        let url = makeURL("/api/clock/toggle", token: token)
        var body = ""
        if let lat = lat, let lng = lng {
            body = "lat=\(lat)&lng=\(lng)"
        }
        return try await performRequest(postRequest(url: url, body: body))
    }

    func sendLocation(token: String, lat: Double, lng: Double, accuracy: Double) async throws -> LocationResponse {
        let url = makeURL("/api/clock/location", token: token)
        let body = "lat=\(lat)&lng=\(lng)&accuracy=\(accuracy)"
        return try await performRequest(postRequest(url: url, body: body))
    }

    func history(token: String) async throws -> HistoryResponse {
        let url = makeURL("/api/clock/history", token: token)
        return try await performRequest(URLRequest(url: url))
    }

    func checkLocation(token: String, lat: Double, lng: Double) async throws -> CheckLocationResponse {
        let url = makeURL("/api/clock/check-location", token: token)
        let body = "lat=\(lat)&lng=\(lng)"
        return try await performRequest(postRequest(url: url, body: body))
    }

    private func performRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ApiError.badResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw ApiError.server(http.statusCode)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ApiError.decoding(error.localizedDescription)
        }
    }

    private func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}