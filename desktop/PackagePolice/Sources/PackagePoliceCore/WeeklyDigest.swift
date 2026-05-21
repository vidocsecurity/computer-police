import Foundation

public struct WeeklyDigest: Equatable, Sendable {
    public let generatedAt: Date
    public let stats: APIStats
    public let recentEvents: [DigestEvent]
    public let vulnerableEvents: [DigestEvent]
    public let malwareEvents: [DigestEvent]
    public let preventedCount: Int
    public let recommendations: [DigestRecommendation]

    public var installsThisWeek: Int { stats.installs }
    public var vulnerableCount: Int { vulnerableEvents.count }
    public var malwarePreventionCount: Int { malwareEvents.count }

    public static func build(
        stats: APIStats,
        events: [PackageEvent],
        blocklist: Blocklist,
        now: Date = Date())
        -> WeeklyDigest
    {
        let digestEvents = events
            .filter { $0.request.type != "other" && $0.request.package != nil }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .map { event -> DigestEvent in
                let match = blocklist.match(event: event)
                return DigestEvent(event: event, blocklistEntry: match)
            }

        let malware = digestEvents.filter { $0.isMalwarePrevented }
        let vulnerable = digestEvents.filter { $0.blocklistEntry != nil || $0.isMalwarePrevented }
        let recommendations = Dictionary(grouping: vulnerable) { digestEvent in
            digestEvent.packageName + "@" + (digestEvent.version ?? "")
        }
        .values
        .compactMap { events -> DigestRecommendation? in
            guard let first = events.first else { return nil }
            if let entry = first.blocklistEntry {
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
            guard let advisoryID = first.blockedBy else { return nil }
            return DigestRecommendation(
                id: advisoryID,
                packageName: first.packageName,
                version: first.version,
                severity: "critical",
                advisoryID: advisoryID,
                summary: first.blockReason ?? "Computer Police blocked this package metadata or tarball.",
                recommendation: "Do not install this version. Rebuild from a trusted lockfile after choosing a safe release.",
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
            malwareEvents: malware,
            preventedCount: stats.blocked,
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
    public var blockedBy: String? { event.request.blockedBy }
    public var blockReason: String? { event.request.blockReason }
    public var isVulnerable: Bool { blocklistEntry != nil }
    public var isBlocked: Bool { statusCode == 403 }
    public var isMalwarePrevented: Bool { isBlocked && blockedBy != nil }
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
