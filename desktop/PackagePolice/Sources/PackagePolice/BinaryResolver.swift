import Foundation

struct ResolvedBinary {
    let url: URL
    let status: BinaryStatus
}

struct BinaryResolver {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func locate(userConfiguredPath: String) -> ResolvedBinary? {
        if let bundled = bundledBinaryURL(), isExecutable(bundled.path) {
            return ResolvedBinary(url: bundled, status: .bundled)
        }
        if !userConfiguredPath.isEmpty, isExecutable(userConfiguredPath) {
            return ResolvedBinary(url: URL(fileURLWithPath: userConfiguredPath), status: .configured)
        }
        for path in pathCandidates() where isExecutable(path) {
            return ResolvedBinary(url: URL(fileURLWithPath: path), status: .path)
        }
        return nil
    }

    private func bundledBinaryURL() -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("package-police")
    }

    private func pathCandidates() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var candidates = [
            "\(home)/.local/bin/package-police",
            "/opt/homebrew/bin/package-police",
            "/usr/local/bin/package-police",
        ]
        let pathEntries = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        candidates.append(contentsOf: pathEntries.map { "\($0)/package-police" })
        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func isExecutable(_ path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }
}
