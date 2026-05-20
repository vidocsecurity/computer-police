import SwiftUI

struct StatusLightView: View {
    @ObservedObject var store: SecurityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                light("Binary", store.binaryStatus.rawValue, color: store.binaryStatus == .missing ? .red : .green)
                light("Proxy", store.proxyStatus.rawValue, color: proxyColor)
                light("Registry", store.registryStatus.rawValue, color: registryColor)
            }
            HStack(spacing: 12) {
                light("Malware", malwareStatusText, color: malwareColor)
                if let progress = malwareProgressText {
                    Text(progress)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private func light(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text("\(label): \(value)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var proxyColor: Color {
        switch store.proxyStatus {
        case .running: return .green
        case .restarting: return .yellow
        case .unreachable: return .red
        case .stopped: return .secondary
        }
    }

    private var registryColor: Color {
        switch store.registryStatus {
        case .enabled: return .green
        case .mismatch: return .yellow
        case .disabled: return .secondary
        }
    }

    private var malwareStatusText: String {
        guard let status = store.advisoryStatus else { return "Unknown" }
        switch status.state {
        case "syncing": return "Syncing"
        case "ready": return "\(status.advisoryCount) rules"
        case "stale": return "Stale"
        case "error": return "Error"
        default: return "Empty"
        }
    }

    private var malwareColor: Color {
        guard let status = store.advisoryStatus else { return .secondary }
        switch status.state {
        case "ready": return .green
        case "syncing": return .yellow
        case "stale": return .orange
        case "error": return .red
        default: return .secondary
        }
    }

    private var malwareProgressText: String? {
        guard let status = store.advisoryStatus, status.state == "syncing" else { return nil }
        guard let total = status.totalBytes, total > 0, let downloaded = status.downloadedBytes else {
            return "Downloading advisory feed"
        }
        let percent = Int((Double(downloaded) / Double(total) * 100).rounded())
        return "Downloading \(min(percent, 100))%"
    }
}
