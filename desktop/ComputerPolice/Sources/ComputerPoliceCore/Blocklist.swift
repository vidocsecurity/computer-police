import Foundation

public struct BlocklistEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { advisoryID + ":" + name }
    public let name: String
    public let versions: [String]
    public let advisoryID: String
    public let severity: String
    public let summary: String
    public let recommendation: String

    enum CodingKeys: String, CodingKey {
        case name
        case versions
        case advisoryID = "advisory_id"
        case severity
        case summary
        case recommendation
    }
}

public struct Blocklist: Codable, Equatable, Sendable {
    public let entries: [BlocklistEntry]

    public init(entries: [BlocklistEntry]) {
        self.entries = entries
    }

    public static func loadBundled() -> Blocklist {
        for url in bundledResourceCandidates() {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Blocklist.self, from: data)
            else {
                continue
            }
            return decoded
        }
        return Blocklist(entries: [])
    }

    public func match(package: String?, version: String?) -> BlocklistEntry? {
        guard let package, let version else { return nil }
        return entries.first { entry in
            entry.name == package && entry.versions.contains(version)
        }
    }

    public func match(event: PackageEvent) -> BlocklistEntry? {
        match(package: event.request.package, version: event.request.version)
    }

    private static func bundledResourceCandidates() -> [URL] {
        let resourceBundleName = "ComputerPolice_ComputerPoliceCore.bundle"
        let appResourceURL = Bundle.main.resourceURL?
            .appendingPathComponent(resourceBundleName, isDirectory: true)
            .appendingPathComponent("blocklist.json")
        let sourceTreeURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("blocklist.json")
        return [appResourceURL, sourceTreeURL].compactMap { $0 }
    }
}
