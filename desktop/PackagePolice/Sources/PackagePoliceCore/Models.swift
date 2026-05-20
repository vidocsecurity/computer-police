import Foundation

public struct APIHealth: Codable, Equatable, Sendable {
    public let status: String
    public let version: String
    public let pid: Int
    public let address: String
    public let upstream: String
}

public struct APIEventsResponse: Codable, Equatable, Sendable {
    public let events: [PackageEvent]
}

public struct APIStats: Codable, Equatable, Sendable {
    public let window: String
    public let windowStart: String
    public let windowEnd: String
    public let installs: Int
    public let uniquePackages: Int
    public let blocked: Int
    public let byManager: [String: Int]
    public let topPackages: [TopPackage]
    public let ledgerPath: String
    public let lastUpdatedAt: String?

    enum CodingKeys: String, CodingKey {
        case window
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case installs
        case uniquePackages = "unique_packages"
        case blocked
        case byManager = "by_manager"
        case topPackages = "top_packages"
        case ledgerPath = "ledger_path"
        case lastUpdatedAt = "last_updated_at"
    }

    public static let empty = APIStats(
        window: "week",
        windowStart: "",
        windowEnd: "",
        installs: 0,
        uniquePackages: 0,
        blocked: 0,
        byManager: [:],
        topPackages: [],
        ledgerPath: "",
        lastUpdatedAt: nil)
}

public struct TopPackage: Codable, Equatable, Identifiable, Sendable {
    public var id: String { package + "@" + (version ?? "") }
    public let package: String
    public let version: String?
    public let count: Int
}

public struct PackageEvent: Codable, Equatable, Identifiable, Sendable {
    public let schemaVersion: String
    public let eventType: String
    public let eventID: String
    public let timestamp: String
    public let source: String
    public let request: EventRequest
    public let upstream: EventUpstream
    public let client: EventClient
    public let privacy: EventPrivacy

    public var id: String { eventID }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case eventType = "event_type"
        case eventID = "event_id"
        case timestamp
        case source
        case request
        case upstream
        case client
        case privacy
    }
}

public struct EventRequest: Codable, Equatable, Sendable {
    public let method: String
    public let path: String
    public let type: String
    public let package: String?
    public let version: String?
    public let statusCode: Int
    public let durationMS: Int

    enum CodingKeys: String, CodingKey {
        case method
        case path
        case type
        case package
        case version
        case statusCode = "status_code"
        case durationMS = "duration_ms"
    }
}

public struct EventUpstream: Codable, Equatable, Sendable {
    public let registry: String
}

public struct EventClient: Codable, Equatable, Sendable {
    public let userAgent: String?
    public let packageManagerGuess: String?
    public let remoteAddr: String?

    enum CodingKeys: String, CodingKey {
        case userAgent = "user_agent"
        case packageManagerGuess = "package_manager_guess"
        case remoteAddr = "remote_addr"
    }
}

public struct EventPrivacy: Codable, Equatable, Sendable {
    public let authHeadersLogged: Bool
    public let bodyLogged: Bool

    enum CodingKeys: String, CodingKey {
        case authHeadersLogged = "auth_headers_logged"
        case bodyLogged = "body_logged"
    }
}

public extension PackageEvent {
    var packageCoordinate: String {
        guard let package = request.package, !package.isEmpty else { return "-" }
        if let version = request.version, !version.isEmpty {
            return "\(package)@\(version)"
        }
        return package
    }

    var date: Date? {
        Self.parseDate(timestamp)
    }

    private static func parseDate(_ timestamp: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: timestamp) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: timestamp)
    }
}
