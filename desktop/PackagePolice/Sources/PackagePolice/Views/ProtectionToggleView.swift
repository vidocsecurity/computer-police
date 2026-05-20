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
                Text(store.protectionState.detail)
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
        case .on: return store.digest.vulnerableCount > 0 ? .orange : .green
        case .degraded, .starting, .stopping: return .yellow
        case .failed: return .red
        case .off: return .secondary
        }
    }
}
