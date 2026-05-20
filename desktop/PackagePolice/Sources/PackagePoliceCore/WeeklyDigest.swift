import Foundation

public struct WeeklyDigest: Equatable, Sendable {
    public let generatedAt: Date
    public let stats: APIStats
    public let recentEvents: [DigestEvent]
    public let vulnerableEvents: [DigestEvent]
    public let preventedCount: Int
    public let recommendations: [DigestRecommendation]

    public var installsThisWeek: Int { stats.installs }
    public var vulnerableCount: Int { vulnerableEvents.count }

    public static func build(
        stats: APIStats,
        events: [PackageEvent],
        blocklist: Blocklist,
        now: Date = Date())
        -> WeeklyDigest
    {
        let digestEvents = events
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .map { event -> DigestEvent in
                let match = blocklist.match(event: event)
                return DigestEvent(event: event, blocklistEntry: match)
            }

        let vulnerable = digestEvents.filter { $0.blocklistEntry != nil }
        let recommendations = Dictionary(grouping: vulnerable) { digestEvent in
            digestEvent.packageName + "@" + (digestEvent.version ?? "")
        }
        .values
        .compactMap { events -> DigestRecommendation? in
            guard let first = events.first, let entry = first.blocklistEntry else { return nil }
            return DigestRecommendation(
                id: entry.id,
                packageName: first.packageName,
                version: first.version,
                severity: entry.severity,
                advisoryID: entry.advisoryID,
                summary: entry.summary,
                recommendation: entry.recommendation,
                count: events.count)
        }
        .sorted { lhs, rhs in
            if severityRank(lhs.severity) != severityRank(rhs.severity) {
                return severityRank(lhs.severity) > severityRank(rhs.severity)
            }
            return lhs.packageName < rhs.packageName
        }

        return WeeklyDigest(
            generatedAt: now,
            stats: stats,
            recentEvents: Array(digestEvents.prefix(10)),
            vulnerableEvents: vulnerable,
            preventedCount: vulnerable.count,
            recommendations: recommendations)
    }
}

public struct DigestEvent: Equatable, Identifiable, Sendable {
    public let event: PackageEvent
    public let blocklistEntry: BlocklistEntry?

    public var id: String { event.id }
    public var packageName: String { event.request.package ?? "-" }
    public var version: String? { event.request.version }
    public var coordinate: String { event.packageCoordinate }
    public var manager: String { event.client.packageManagerGuess ?? "unknown" }
    public var requestType: String { event.request.type }
    public var statusCode: Int { event.request.statusCode }
    public var isVulnerable: Bool { blocklistEntry != nil }
    public var isBlocked: Bool { statusCode == 403 }
}

public struct DigestRecommendation: Equatable, Identifiable, Sendable {
    public let id: String
    public let packageName: String
    public let version: String?
    public let severity: String
    public let advisoryID: String
    public let summary: String
    public let recommendation: String
    public let count: Int

    public var coordinate: String {
        guard let version, !version.isEmpty else { return packageName }
        return "\(packageName)@\(version)"
    }
}

private func severityRank(_ severity: String) -> Int {
    switch severity.lowercased() {
    case "critical": return 4
    case "high": return 3
    case "medium": return 2
    case "low": return 1
    default: return 0
    }
}
