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

public struct APIAdvisories: Codable, Equatable, Sendable {
    public let malware: MalwareAdvisoryStatus
}

public struct MalwareAdvisoryStatus: Codable, Equatable, Sendable {
    public let state: String
    public let advisoryCount: Int
    public let cachePath: String
    public let sourceURL: String
    public let lastStartedAt: String?
    public let lastSyncedAt: String?
    public let nextRefreshAt: String?
    public let lastError: String?
    public let downloadedBytes: Int64?
    public let totalBytes: Int64?
    public let ageSeconds: Int64?
    public let refreshIntervalSeconds: Int64?
    public let freshForSeconds: Int64?
    public let staleBySeconds: Int64?

    public var freshnessSummary: String {
        if let staleBySeconds, staleBySeconds > 0 {
            return "stale by \(Self.shortDuration(staleBySeconds))"
        }
        if let ageSeconds {
            return "updated \(Self.shortDuration(ageSeconds)) ago"
        }
        return "freshness unknown"
    }

    enum CodingKeys: String, CodingKey {
        case state
        case advisoryCount = "advisory_count"
        case cachePath = "cache_path"
        case sourceURL = "source_url"
        case lastStartedAt = "last_started_at"
        case lastSyncedAt = "last_synced_at"
        case nextRefreshAt = "next_refresh_at"
        case lastError = "last_error"
        case downloadedBytes = "downloaded_bytes"
        case totalBytes = "total_bytes"
        case ageSeconds = "age_seconds"
        case refreshIntervalSeconds = "refresh_interval_seconds"
        case freshForSeconds = "fresh_for_seconds"
        case staleBySeconds = "stale_by_seconds"
    }

    private static func shortDuration(_ seconds: Int64) -> String {
        let seconds = max(0, seconds)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 48 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
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
    public let blockedBy: String?
    public let blockReason: String?

    enum CodingKeys: String, CodingKey {
        case method
        case path
        case type
        case package
        case version
        case statusCode = "status_code"
        case durationMS = "duration_ms"
        case blockedBy = "blocked_by"
        case blockReason = "block_reason"
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
