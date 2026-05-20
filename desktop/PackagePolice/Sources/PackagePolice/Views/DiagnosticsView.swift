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
                row("PID", store.health.map { String($0.pid) } ?? "-")
                row("Address", store.health?.address ?? "127.0.0.1:4873")
                row("Ledger", store.stats.ledgerPath.isEmpty ? "~/.package-police/registry-proxy/events.ndjson" : store.stats.ledgerPath)
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
}
