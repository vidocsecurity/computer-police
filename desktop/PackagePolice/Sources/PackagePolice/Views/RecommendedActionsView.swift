import SwiftUI

/// Renders nothing when there's nothing to do. Shows a "WANTED" panel with
/// one or more action cards otherwise. Replaces the old always-on cluster.
struct RecommendedActionsView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    @Environment(\.retro) private var palette

    var body: some View {
        let items = actions
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "Wanted")
                    Spacer()
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.retroCaption)
                        .foregroundStyle(palette.textTertiary)
                }
                BeveledPanel(style: .raised, padding: 10) {
                    VStack(spacing: 8) {
                        ForEach(items) { action in
                            actionRow(action)
                            if action.id != items.last?.id {
                                Rectangle()
                                    .fill(palette.bevelShadow.opacity(0.4))
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ action: ActionItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Rectangle()
                    .fill(action.color.opacity(0.18))
                    .frame(width: 18, height: 18)
                    .overlay(Rectangle().stroke(action.color, lineWidth: 1))
                Image(systemName: action.icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(action.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title.uppercased())
                    .font(.retroLabel)
                    .tracking(0.6)
                    .foregroundStyle(palette.textPrimary)
                Text(action.detail)
                    .font(.retroBody)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let button = action.button {
                    Button(button.title) {
                        Task { await button.run(protection) }
                    }
                    .buttonStyle(BeveledButtonStyle(emphasis: .primary))
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
    }

    private var actions: [ActionItem] {
        var items: [ActionItem] = []
        if case let .degraded(reason) = store.protectionState {
            items.append(ActionItem(
                title: "Repair protection",
                detail: reason,
                icon: "wrench.and.screwdriver",
                color: palette.warning,
                button: ActionButton(title: "Repair", run: { await $0.repair() })))
        }
        if case let .failed(reason) = store.protectionState {
            items.append(ActionItem(
                title: "Restart proxy",
                detail: reason,
                icon: "arrow.clockwise.circle",
                color: palette.critical,
                button: ActionButton(title: "Retry", run: { await $0.restart() })))
        }
        for recommendation in store.digest.recommendations.prefix(3) {
            items.append(ActionItem(
                title: "Review \(recommendation.coordinate)",
                detail: "\(recommendation.advisoryID): \(recommendation.recommendation)",
                icon: "exclamationmark.triangle.fill",
                color: palette.warning,
                button: nil))
        }
        return items
    }
}

private struct ActionItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let button: ActionButton?
}

private struct ActionButton {
    let title: String
    let run: (ProtectionController) async -> Void
}
