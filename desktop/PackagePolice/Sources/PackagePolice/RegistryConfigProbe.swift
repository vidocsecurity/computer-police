import Foundation

struct RegistryConfigProbe {
    private let fileManager: FileManager
    private let registryURL = "http://127.0.0.1:4873"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func status() -> RegistryStatus {
        let npm = npmStatus()
        let bun = bunStatus()
        if npm == .enabled || bun == .enabled {
            return .enabled
        }
        if npm == .mismatch || bun == .mismatch {
            return .mismatch
        }
        return .disabled
    }

    private func npmStatus() -> RegistryStatus {
        let path = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".npmrc").path
        guard let content = try? String(contentsOfFile: path) else { return .disabled }
        let registryLines = content
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("registry=") }
        guard !registryLines.isEmpty else { return .disabled }
        return registryLines.contains { $0.contains(registryURL) } ? .enabled : .mismatch
    }

    private func bunStatus() -> RegistryStatus {
        let contents = bunfigPaths().compactMap { try? String(contentsOfFile: $0) }
        guard !contents.isEmpty else { return .disabled }
        let content = contents.joined(separator: "\n")
        let registryLines = content
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("registry") }
        guard !registryLines.isEmpty else { return .disabled }
        return registryLines.contains { $0.contains(registryURL) } ? .enabled : .mismatch
    }

    private func bunfigPaths() -> [String] {
        var paths: [String] = []
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            paths.append((xdg as NSString).appendingPathComponent("bun/bunfig.toml"))
            paths.append((xdg as NSString).appendingPathComponent(".bunfig.toml"))
        }
        paths.append(fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".bunfig.toml").path)
        return paths
    }
}
