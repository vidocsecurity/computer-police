import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(.title2.bold())
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                row("Binary", store.binaryStatus.rawValue)
                row("Proxy", store.proxyStatus.rawValue)
                row("Registry", store.registryStatus.rawValue)
                row("Malware advisories", advisorySummary)
                row("PID", store.health.map { String($0.pid) } ?? "-")
                row("Address", store.health?.address ?? "127.0.0.1:4873")
                row("Ledger", store.stats.ledgerPath.isEmpty ? "~/.package-police/registry-proxy/events.ndjson" : store.stats.ledgerPath)
                if let cachePath = store.advisoryStatus?.cachePath, !cachePath.isEmpty {
                    row("Advisory cache", cachePath)
                }
                if let restarted = store.lastRestartAt {
                    row("Last restart", restarted.formatted(date: .omitted, time: .standard))
                }
                if let error = store.lastError {
                    row("Last error", error)
                }
            }
            HStack {
                Button("Restart Proxy") { Task { await protection.restart() } }
                Button("Repair Registry") { Task { await protection.repair() } }
                Button("Install CLI") { Task { await protection.installCLIForShell() } }
            }
            Spacer()
        }
        .padding(20)
    }

    private func row(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .font(.caption)
    }

    private var advisorySummary: String {
        guard let status = store.advisoryStatus else { return "Unknown" }
        if status.state == "syncing" {
            if let total = status.totalBytes, total > 0, let downloaded = status.downloadedBytes {
                let percent = Int((Double(downloaded) / Double(total) * 100).rounded())
                return "Syncing \(min(percent, 100))%"
            }
            return "Syncing"
        }
        if status.state == "error" {
            return "Error: \(status.lastError ?? "unknown error")"
        }
        return "\(status.state.capitalized), \(status.advisoryCount) rules"
    }
}
