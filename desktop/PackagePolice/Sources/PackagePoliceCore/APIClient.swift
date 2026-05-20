import Foundation

public final class APIClient: @unchecked Sendable {
    public enum APIError: Error, LocalizedError {
        case badStatus(Int)

        public var errorDescription: String? {
            switch self {
            case let .badStatus(status):
                return "Package Police API returned HTTP \(status)"
            }
        }
    }

    public struct StatsResult: Sendable {
        public let stats: APIStats?
        public let etag: String?
        public let notModified: Bool
    }

    private let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:4873")!,
        session: URLSession = .shared)
    {
        self.baseURL = baseURL
        self.session = session
    }

    public func health() async throws -> APIHealth {
        try await get(APIHealth.self, path: "/api/health")
    }

    public func events(limit: Int = 100) async throws -> [PackageEvent] {
        var components = URLComponents(url: url(path: "/api/events"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        let response = try await get(APIEventsResponse.self, url: components.url!)
        return response.events
    }

    public func stats(window: String = "week", ifNoneMatch: String? = nil) async throws -> StatsResult {
        var components = URLComponents(url: url(path: "/api/stats"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "window", value: window)]
        var request = URLRequest(url: components.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let ifNoneMatch {
            request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(-1)
        }
        let etag = http.value(forHTTPHeaderField: "ETag")
        if http.statusCode == 304 {
            return StatsResult(stats: nil, etag: etag, notModified: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        return StatsResult(
            stats: try JSONDecoder().decode(APIStats.self, from: data),
            etag: etag,
            notModified: false)
    }

    private func get<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        try await get(type, url: url(path: path))
    }

    private func get<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func url(path: String) -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: base + "/" + trimmed)!
    }
}
