import SwiftUI

struct ProtectionToggleView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text("Protection: \(store.protectionState.title)")
                    .font(.title3.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Changed \(store.lastChangedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.protectionState.isEnabled },
                set: { enabled in
                    Task {
                        if enabled {
                            await protection.enableProtection()
                        } else {
                            await protection.disableProtection()
                        }
                    }
                }))
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var color: Color {
        switch store.protectionState {
        case .on: return store.digest.malwarePreventionCount > 0 ? .red : .green
        case .degraded, .starting, .stopping: return .yellow
        case .failed: return .red
        case .off: return .secondary
        }
    }

    private var detail: String {
        if case .starting = store.protectionState,
           let status = store.advisoryStatus,
           status.state == "syncing"
        {
            if let total = status.totalBytes, total > 0, let downloaded = status.downloadedBytes {
                let percent = Int((Double(downloaded) / Double(total) * 100).rounded())
                return "Downloading malware advisories (\(min(percent, 100))%)."
            }
            return "Downloading malware advisories."
        }
        return store.protectionState.detail
    }
}
