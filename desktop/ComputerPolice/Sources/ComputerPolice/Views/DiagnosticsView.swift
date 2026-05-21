import SwiftUI

/// "Open case file" — inline disclosure version. Uses dotted-leader rows so
/// it reads like a 90s INI inspector. Replaces the old modal sheet entirely.
struct DiagnosticsView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    @Environment(\.retro) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "Case File")
            BeveledPanel(style: .sunken, padding: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    rows
                    Rectangle()
                        .fill(palette.bevelShadow.opacity(0.4))
                        .frame(height: 1)
                        .padding(.top, 2)
                    HStack(spacing: 6) {
                        Button("Restart") { Task { await protection.restart() } }
                            .buttonStyle(BeveledButtonStyle())
                        Button("Repair") { Task { await protection.repair() } }
                            .buttonStyle(BeveledButtonStyle())
                        Button("Install CLI") { Task { await protection.installCLIForShell() } }
                            .buttonStyle(BeveledButtonStyle())
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        DottedLeaderRow(key: "Binary", value: store.binaryStatus.rawValue)
        DottedLeaderRow(key: "Proxy", value: store.proxyStatus.rawValue)
        DottedLeaderRow(key: "Registry", value: store.registryStatus.rawValue)
        DottedLeaderRow(key: "Advisories", value: advisorySummary)
        DottedLeaderRow(key: "PID", value: store.health.map { String($0.pid) } ?? "—")
        DottedLeaderRow(key: "Address", value: store.health?.address ?? "127.0.0.1:4873")
        DottedLeaderRow(
            key: "Ledger",
            value: store.stats.ledgerPath.isEmpty
                ? "~/.computer-police/registry-proxy/events.ndjson"
                : store.stats.ledgerPath)
        if let cachePath = store.advisoryStatus?.cachePath, !cachePath.isEmpty {
            DottedLeaderRow(key: "Cache", value: cachePath)
        }
        if let restarted = store.lastRestartAt {
            DottedLeaderRow(
                key: "Last restart",
                value: restarted.formatted(date: .omitted, time: .standard))
        }
        if let error = store.lastError {
            DottedLeaderRow(
                key: "Last error",
                value: error,
                valueAccent: palette.critical)
        }
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
