import XCTest
@testable import PackagePoliceCore

final class BlocklistTests: XCTestCase {
    func testMatchesPackageAndVersion() {
        let blocklist = Blocklist(entries: [
            BlocklistEntry(
                name: "ua-parser-js",
                versions: ["0.7.29"],
                advisoryID: "GHSA-test",
                severity: "critical",
                summary: "bad",
                recommendation: "upgrade"),
        ])

        XCTAssertNotNil(blocklist.match(package: "ua-parser-js", version: "0.7.29"))
        XCTAssertNil(blocklist.match(package: "ua-parser-js", version: "0.7.28"))
        XCTAssertNil(blocklist.match(package: "left-pad", version: "1.3.0"))
    }

    func testBundledBlocklistLoads() {
        let blocklist = Blocklist.loadBundled()
        XCTAssertFalse(blocklist.entries.isEmpty)
        XCTAssertNotNil(blocklist.match(package: "ua-parser-js", version: "0.7.29"))
    }
}
