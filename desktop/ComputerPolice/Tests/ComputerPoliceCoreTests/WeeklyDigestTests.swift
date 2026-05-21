import XCTest
@testable import ComputerPoliceCore

final class WeeklyDigestTests: XCTestCase {
    func testDigestCountsBlockedMalwarePreventions() {
        let stats = APIStats(
            window: "week",
            windowStart: "2026-05-13T12:00:00Z",
            windowEnd: "2026-05-20T12:00:00Z",
            installs: 3,
            uniquePackages: 2,
            blocked: 1,
            byManager: ["npm": 3],
            topPackages: [],
            ledgerPath: "/tmp/events.ndjson",
            lastUpdatedAt: nil)
        let blocklist = Blocklist(entries: [
            BlocklistEntry(
                name: "ua-parser-js",
                versions: ["0.7.29"],
                advisoryID: "GHSA-test",
                severity: "critical",
                summary: "Compromised release",
                recommendation: "Upgrade"),
        ])

        let digest = WeeklyDigest.build(
            stats: stats,
            events: [
                event(id: "benign", package: "left-pad", version: "1.3.0"),
                event(
                    id: "bad",
                    package: "ua-parser-js",
                    version: "0.7.29",
                    statusCode: 403,
                    blockedBy: "MAL-2026-test",
                    blockReason: "Blocked test malware advisory"),
            ],
            blocklist: blocklist)

        XCTAssertEqual(digest.installsThisWeek, 3)
        XCTAssertEqual(digest.vulnerableCount, 1)
        XCTAssertEqual(digest.malwarePreventionCount, 1)
        XCTAssertEqual(digest.preventedCount, 1)
        XCTAssertEqual(digest.recommendations.first?.advisoryID, "GHSA-test")
    }

    private func event(
        id: String,
        package: String,
        version: String,
        statusCode: Int = 200,
        blockedBy: String? = nil,
        blockReason: String? = nil)
        -> PackageEvent
    {
        PackageEvent(
            schemaVersion: "1.0",
            eventType: "registry_request_observed",
            eventID: id,
            timestamp: "2026-05-20T12:00:00Z",
            source: "local_registry_proxy",
            request: EventRequest(
                method: "GET",
                path: "/\(package)",
                type: "tarball",
                package: package,
                version: version,
                statusCode: statusCode,
                durationMS: 10,
                blockedBy: blockedBy,
                blockReason: blockReason),
            upstream: EventUpstream(registry: "https://registry.npmjs.org/"),
            client: EventClient(userAgent: "npm/test", packageManagerGuess: "npm", remoteAddr: "127.0.0.1"),
            privacy: EventPrivacy(authHeadersLogged: false, bodyLogged: false))
    }
}
