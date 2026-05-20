import SwiftUI

struct StatusLightView: View {
    @ObservedObject var store: SecurityStore

    var body: some View {
        HStack(spacing: 12) {
            light("Binary", store.binaryStatus.rawValue, color: store.binaryStatus == .missing ? .red : .green)
            light("Proxy", store.proxyStatus.rawValue, color: proxyColor)
            light("Registry", store.registryStatus.rawValue, color: registryColor)
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
}
