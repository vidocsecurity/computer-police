import SwiftUI

struct RecommendedActionsView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended actions")
                .font(.headline)
            if actions.isEmpty {
                Label("No action needed right now.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                ForEach(actions) { action in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: action.icon)
                            .foregroundStyle(action.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title)
                                .font(.caption.bold())
                            Text(action.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let button = action.button {
                                Button(button.title) {
                                    Task { await button.run(protection) }
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var actions: [ActionItem] {
        var items: [ActionItem] = []
        if case let .degraded(reason) = store.protectionState {
            items.append(ActionItem(
                title: "Repair protection",
                detail: reason,
                icon: "wrench.and.screwdriver",
                color: .yellow,
                button: ActionButton(title: "Repair", run: { await $0.repair() })))
        }
        if case let .failed(reason) = store.protectionState {
            items.append(ActionItem(
                title: "Restart proxy",
                detail: reason,
                icon: "arrow.clockwise.circle",
                color: .red,
                button: ActionButton(title: "Retry", run: { await $0.restart() })))
        }
        for recommendation in store.digest.recommendations.prefix(3) {
            items.append(ActionItem(
                title: "Review \(recommendation.coordinate)",
                detail: "\(recommendation.advisoryID): \(recommendation.recommendation)",
                icon: "exclamationmark.triangle.fill",
                color: .orange,
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
