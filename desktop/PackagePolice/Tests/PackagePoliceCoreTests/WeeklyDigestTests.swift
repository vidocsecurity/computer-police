import XCTest
@testable import PackagePoliceCore

final class WeeklyDigestTests: XCTestCase {
    func testDigestCountsBlocklistMatchesAsVulnerableAndPrevented() {
        let stats = APIStats(
            window: "week",
            windowStart: "2026-05-13T12:00:00Z",
            windowEnd: "2026-05-20T12:00:00Z",
            installs: 3,
            uniquePackages: 2,
            blocked: 0,
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
                event(id: "bad", package: "ua-parser-js", version: "0.7.29"),
            ],
            blocklist: blocklist)

        XCTAssertEqual(digest.installsThisWeek, 3)
        XCTAssertEqual(digest.vulnerableCount, 1)
        XCTAssertEqual(digest.preventedCount, 1)
        XCTAssertEqual(digest.recommendations.first?.coordinate, "ua-parser-js@0.7.29")
    }

    private func event(id: String, package: String, version: String) -> PackageEvent {
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
                statusCode: 200,
                durationMS: 10),
            upstream: EventUpstream(registry: "https://registry.npmjs.org/"),
            client: EventClient(userAgent: "npm/test", packageManagerGuess: "npm", remoteAddr: "127.0.0.1"),
            privacy: EventPrivacy(authHeadersLogged: false, bodyLogged: false))
    }
}
