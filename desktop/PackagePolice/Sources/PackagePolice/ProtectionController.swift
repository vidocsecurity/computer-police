import Foundation
import PackagePoliceCore

@MainActor
final class ProtectionController: ObservableObject {
    private let store: SecurityStore
    private let client: APIClient
    private let binaryResolver = BinaryResolver()
    private let registryProbe = RegistryConfigProbe()
    private let notifier: Notifier
    private let heartbeat: Heartbeat
    private let watchdog = Watchdog()
    private var binary: ResolvedBinary?
    private var proxyProcess: Process?
    private var restartTask: Task<Void, Never>?

    init(store: SecurityStore, client: APIClient, notifier: Notifier) {
        self.store = store
        self.client = client
        self.notifier = notifier
        self.heartbeat = Heartbeat(client: client)
        self.heartbeat.onResult = { [weak self] result in
            Task { @MainActor in
                self?.handleHeartbeat(result)
            }
        }
    }

    func startMonitoring() {
        resolveBinary()
        store.registryStatus = registryProbe.status()
        heartbeat.start()
    }

    func stopMonitoring() {
        heartbeat.stop()
        restartTask?.cancel()
        restartTask = nil
    }

    func autoEnableIfNeeded() {
        guard store.autoEnableAtLaunch else { return }
        Task { await enableProtection() }
    }

    func enableProtection() async {
        store.setProtectionState(.starting)
        guard resolveBinary() else {
            fail("Package Police CLI binary is missing.")
            return
        }
        do {
            try await ensureProxyRunning()
            try await runCLI(["proxy", "enable"])
            store.registryStatus = registryProbe.status()
            if store.registryStatus == .enabled {
                store.proxyStatus = .running
                store.setProtectionState(.on)
            } else {
                degrade("Proxy is running, but npm/bun registry settings do not point at Package Police.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func disableProtection() async {
        store.setProtectionState(.stopping)
        guard resolveBinary() else {
            store.proxyStatus = .stopped
            store.registryStatus = .disabled
            store.setProtectionState(.off)
            return
        }
        _ = try? await runCLI(["proxy", "disable"])
        _ = try? await runCLI(["proxy", "stop"])
        stopOwnedProcess()
        store.proxyStatus = .stopped
        store.registryStatus = registryProbe.status()
        store.setProtectionState(.off)
    }

    func repair() async {
        guard resolveBinary() else {
            fail("Package Police CLI binary is missing.")
            return
        }
        do {
            try await ensureProxyRunning()
            try await runCLI(["proxy", "enable"])
            store.registryStatus = registryProbe.status()
            if store.registryStatus == .enabled {
                store.setProtectionState(.on)
            } else {
                degrade("Registry override is still missing after repair.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func restart() async {
        guard resolveBinary() else {
            fail("Package Police CLI binary is missing.")
            return
        }
        store.proxyStatus = .restarting
        _ = try? await runCLI(["proxy", "stop"])
        stopOwnedProcess()
        do {
            try await ensureProxyRunning(forceSpawn: true)
            store.lastRestartAt = Date()
            if store.registryStatus == .enabled {
                store.setProtectionState(.on)
            } else {
                degrade("Proxy restarted, but registry settings need repair.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func installCLIForShell() async {
        guard let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("package-police")
        else {
            fail("Bundled CLI binary was not found.")
            return
        }
        let destinationDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin", isDirectory: true)
        let destination = destinationDir.appendingPathComponent("package-police")
        do {
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: bundled, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            store.userConfiguredBinaryPath = destination.path
            _ = resolveBinary()
        } catch {
            fail(error.localizedDescription)
        }
    }

    func applicationWillTerminate() {
        stopMonitoring()
        guard !store.keepProxyRunningOnQuit else { return }
        if binary != nil {
            Task { await disableProtection() }
        }
    }

    @discardableResult
    private func resolveBinary() -> Bool {
        binary = binaryResolver.locate(userConfiguredPath: store.userConfiguredBinaryPath)
        if let binary {
            store.binaryStatus = binary.status
            return true
        }
        store.binaryStatus = .missing
        return false
    }

    private func ensureProxyRunning(forceSpawn: Bool = false) async throws {
        if !forceSpawn, (try? await client.health()) != nil {
            store.proxyStatus = .running
            return
        }
        try spawnProxy()
        let deadline = Date().addingTimeInterval(5)
        var lastError: Error?
        while Date() < deadline {
            do {
                store.health = try await client.health()
                store.proxyStatus = .running
                return
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        throw lastError ?? NSError(domain: "PackagePolice", code: 1, userInfo: [NSLocalizedDescriptionKey: "Proxy did not become healthy."])
    }

    private func spawnProxy() throws {
        guard let binary else {
            throw NSError(domain: "PackagePolice", code: 2, userInfo: [NSLocalizedDescriptionKey: "Package Police CLI binary is missing."])
        }
        if let proxyProcess, proxyProcess.isRunning {
            return
        }
        let process = Process()
        process.executableURL = binary.url
        process.arguments = ["proxy", "serve"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        proxyProcess = process
    }

    private func runCLI(_ arguments: [String]) async throws {
        guard let binary else {
            throw NSError(domain: "PackagePolice", code: 2, userInfo: [NSLocalizedDescriptionKey: "Package Police CLI binary is missing."])
        }
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = binary.url
            process.arguments = arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8) ?? "Command failed"
                    continuation.resume(throwing: NSError(
                        domain: "PackagePolice",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)]))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func handleHeartbeat(_ result: Result<APIHealth, Error>) {
        guard !isUserTransitioning else { return }
        switch result {
        case let .success(health):
            watchdog.recordSuccess()
            store.health = health
            store.proxyStatus = .running
            store.registryStatus = registryProbe.status()
            if store.protectionState.isEnabled && store.registryStatus != .enabled {
                degrade("Protection partial - npm/bun registry settings no longer point at Package Police.")
            } else if store.protectionState.isEnabled {
                store.setProtectionState(.on)
            }
        case let .failure(error):
            store.proxyStatus = .unreachable
            guard store.protectionState.isEnabled || store.autoEnableAtLaunch else { return }
            degrade("Proxy heartbeat failed: \(error.localizedDescription)")
            if watchdog.recordFailure() {
                scheduleWatchdogRestart()
            }
        }
    }

    private var isUserTransitioning: Bool {
        if case .starting = store.protectionState { return true }
        if case .stopping = store.protectionState { return true }
        return false
    }

    private func scheduleWatchdogRestart() {
        guard watchdog.canRestart() else {
            fail("Proxy failed repeatedly and automatic restart was paused.")
            return
        }
        let delay = watchdog.recordRestart()
        store.proxyStatus = .restarting
        restartTask?.cancel()
        restartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await restart()
        }
    }

    private func stopOwnedProcess() {
        if let proxyProcess, proxyProcess.isRunning {
            proxyProcess.terminate()
        }
        proxyProcess = nil
    }

    private func degrade(_ reason: String) {
        store.setProtectionState(.degraded(reason))
        store.lastError = reason
        notifier.notifyProtectionIssue(store.protectionState, enabled: store.notificationsEnabled)
    }

    private func fail(_ reason: String) {
        store.proxyStatus = .unreachable
        store.lastError = reason
        store.setProtectionState(.failed(reason))
        notifier.notifyProtectionIssue(store.protectionState, enabled: store.notificationsEnabled)
    }
}
