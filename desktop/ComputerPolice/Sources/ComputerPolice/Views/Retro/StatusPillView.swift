import SwiftUI

/// Single-row status pill: collapsed when everything is healthy, expanded
/// inline when one or more components need attention. Replaces the old
/// always-on four-dot block.
struct StatusPillView: View {
    @ObservedObject var store: SecurityStore

    @Environment(\.retro) private var palette
    @State private var detailsVisible = false

    var body: some View {
        let components = ComponentSnapshot.build(from: store)
        let aggregate = components.aggregate
        let requiresAttention = components.contains { $0.state == .warn || $0.state == .fail }

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                LEDIndicator(state: aggregate, blinking: aggregate == .fail)
                Text(headline(for: aggregate))
                    .font(.retroLabel)
                    .tracking(1.0)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 8)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        detailsVisible.toggle()
                    }
                } label: {
                    Text(detailsVisible ? "Hide" : "Details")
                }
                .buttonStyle(BracketButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            if detailsVisible {
                Rectangle()
                    .fill(palette.bevelShadow.opacity(0.5))
                    .frame(height: 1)
                VStack(spacing: 2) {
                    ForEach(components) { component in
                        componentRow(component)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
        }
        .background(palette.panel)
        .overlay(BevelOverlay(style: .raised))
        .onAppear {
            // Stay expanded if we boot into a degraded state so the user
            // sees what to fix immediately.
            if requiresAttention {
                detailsVisible = true
            }
        }
    }

    private func headline(for state: LEDState) -> String {
        switch state {
        case .ok: return "ALL SYSTEMS NORMAL"
        case .warn: return "STATIONS REPORTING"
        case .fail: return "STATION DOWN"
        case .off: return "STATIONS OFFLINE"
        }
    }

    @ViewBuilder
    private func componentRow(_ component: ComponentSnapshot) -> some View {
        HStack(spacing: 8) {
            LEDIndicator(state: component.state)
            Text(component.label.uppercased())
                .font(.retroLabel)
                .tracking(0.5)
                .foregroundStyle(palette.textPrimary)
                .frame(width: 64, alignment: .leading)
            Text(component.value)
                .font(.retroCaption)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(stateLabel(for: component.state))
                .font(.retroLabel)
                .tracking(0.4)
                .foregroundStyle(stateColor(for: component.state))
        }
    }

    private func stateLabel(for state: LEDState) -> String {
        switch state {
        case .ok: return "OK"
        case .warn: return "WARN"
        case .fail: return "FAIL"
        case .off: return "—"
        }
    }

    private func stateColor(for state: LEDState) -> Color {
        switch state {
        case .ok: return palette.positive
        case .warn: return palette.warning
        case .fail: return palette.critical
        case .off: return palette.textTertiary
        }
    }
}

private struct ComponentSnapshot: Identifiable {
    let label: String
    let value: String
    let state: LEDState

    var id: String { label }

    @MainActor
    static func build(from store: SecurityStore) -> [ComponentSnapshot] {
        var rows: [ComponentSnapshot] = []
        rows.append(ComponentSnapshot(
            label: "Binary",
            value: store.binaryStatus.rawValue,
            state: store.binaryStatus == .missing ? .fail : .ok))
        rows.append(ComponentSnapshot(
            label: "Proxy",
            value: store.proxyStatus.rawValue,
            state: proxyState(store.proxyStatus)))
        rows.append(ComponentSnapshot(
            label: "Registry",
            value: store.registryStatus.rawValue,
            state: registryState(store.registryStatus)))
        let advisory = advisoryRow(store)
        rows.append(advisory)
        return rows
    }

    private static func proxyState(_ status: ProxyStatus) -> LEDState {
        switch status {
        case .running: return .ok
        case .restarting: return .warn
        case .unreachable: return .fail
        case .stopped: return .off
        }
    }

    private static func registryState(_ status: RegistryStatus) -> LEDState {
        switch status {
        case .enabled: return .ok
        case .mismatch: return .warn
        case .disabled: return .off
        }
    }

    @MainActor
    private static func advisoryRow(_ store: SecurityStore) -> ComponentSnapshot {
        guard let status = store.advisoryStatus else {
            return ComponentSnapshot(label: "Malware", value: "Unknown", state: .off)
        }
        switch status.state {
        case "ready":
            return ComponentSnapshot(
                label: "Malware",
                value: "\(status.advisoryCount) rules",
                state: .ok)
        case "syncing":
            let detail: String
            if let total = status.totalBytes, total > 0, let downloaded = status.downloadedBytes {
                let percent = Int((Double(downloaded) / Double(total) * 100).rounded())
                detail = "Syncing \(min(percent, 100))%"
            } else {
                detail = "Syncing"
            }
            return ComponentSnapshot(label: "Malware", value: detail, state: .warn)
        case "stale":
            return ComponentSnapshot(label: "Malware", value: "Stale", state: .warn)
        case "error":
            return ComponentSnapshot(label: "Malware", value: "Error", state: .fail)
        default:
            return ComponentSnapshot(label: "Malware", value: "Empty", state: .off)
        }
    }
}

private extension Array where Element == ComponentSnapshot {
    var aggregate: LEDState {
        if contains(where: { $0.state == .fail }) { return .fail }
        if contains(where: { $0.state == .warn }) { return .warn }
        if allSatisfy({ $0.state == .off }) { return .off }
        return .ok
    }
}
