import ComputerPoliceCore
import SwiftUI

/// Renders nothing when there's nothing to do. Shows a "WANTED" panel with
/// repair-style ops actions and clickable review rows for OSV recommendations
/// the proxy is reporting. Each review row expands inline to a reassurance
/// panel + advisory metadata.
struct RecommendedActionsView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    @Environment(\.retro) private var palette
    @State private var expandedReview: String?

    var body: some View {
        let opsItems = opsActions
        let reviewItems = Array(store.digest.recommendations.prefix(3))
        if opsItems.isEmpty, reviewItems.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "Wanted")
                    Spacer()
                    let total = opsItems.count + reviewItems.count
                    Text("\(total) item\(total == 1 ? "" : "s")")
                        .font(.retroCaption)
                        .foregroundStyle(palette.textTertiary)
                }
                BeveledPanel(style: .raised, padding: 10) {
                    VStack(spacing: 8) {
                        ForEach(opsItems) { action in
                            opsRow(action)
                            divider()
                        }
                        ForEach(Array(reviewItems.enumerated()), id: \.element.id) { idx, recommendation in
                            reviewRow(recommendation)
                            if idx != reviewItems.count - 1 { divider() }
                        }
                    }
                }
            }
            .onAppear { syncFocusedAdvisory() }
            .onChange(of: store.focusedAdvisoryID) { _, _ in syncFocusedAdvisory() }
        }
    }

    private func divider() -> some View {
        Rectangle()
            .fill(palette.bevelShadow.opacity(0.4))
            .frame(height: 1)
    }

    // MARK: - Ops actions (repair / restart)

    @ViewBuilder
    private func opsRow(_ action: OpsAction) -> some View {
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
                Button(action.buttonTitle) {
                    Task { await action.run(protection) }
                }
                .buttonStyle(BeveledButtonStyle(emphasis: .primary))
                .padding(.top, 2)
            }
            Spacer()
        }
    }

    // MARK: - Review row (clickable, inline-expanding)

    @ViewBuilder
    private func reviewRow(_ recommendation: DigestRecommendation) -> some View {
        let expanded = expandedReview == recommendation.id

        VStack(alignment: .leading, spacing: 6) {
            Button {
                toggleExpansion(for: recommendation.id)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Rectangle()
                            .fill(severityColor(recommendation.severity).opacity(0.18))
                            .frame(width: 18, height: 18)
                            .overlay(Rectangle().stroke(severityColor(recommendation.severity), lineWidth: 1))
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(severityColor(recommendation.severity))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Review")
                                .font(.retroLabel)
                                .tracking(0.6)
                                .foregroundStyle(palette.textTertiary)
                            Text(recommendation.coordinate)
                                .font(.retroData)
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Text("\(recommendation.advisoryID) · \(recommendation.summary)")
                            .font(.retroBody)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(expanded ? nil : 1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                AdvisoryDetailPanel(
                    coordinate: recommendation.coordinate,
                    advisoryID: recommendation.advisoryID,
                    severity: recommendation.severity,
                    summary: recommendation.summary,
                    recommendation: recommendation.recommendation,
                    manager: nil,
                    timestamp: nil,
                    outcome: .review)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func toggleExpansion(for id: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedReview == id {
                expandedReview = nil
            } else {
                expandedReview = id
            }
        }
        store.clearFocusedAdvisory(matching: id)
    }

    private func syncFocusedAdvisory() {
        guard let target = store.focusedAdvisoryID else { return }
        if let match = store.digest.recommendations.first(where: { matchesAdvisory(target, $0) }) {
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedReview = match.id
            }
            store.clearFocusedAdvisory(matching: target)
        }
    }

    private func matchesAdvisory(_ target: String, _ recommendation: DigestRecommendation) -> Bool {
        let normalize = { (s: String) in s.uppercased().trimmingCharacters(in: .whitespaces) }
        return normalize(recommendation.advisoryID) == normalize(target)
    }

    private func severityColor(_ severity: String) -> Color {
        OSVAdvisory.severityColor(severity, palette: palette)
    }

    private var opsActions: [OpsAction] {
        var items: [OpsAction] = []
        if case let .degraded(reason) = store.protectionState {
            items.append(OpsAction(
                id: "ops-repair",
                title: "Repair protection",
                detail: reason,
                icon: "wrench.and.screwdriver",
                color: palette.warning,
                buttonTitle: "Repair",
                run: { await $0.repair() }))
        }
        if case let .failed(reason) = store.protectionState {
            items.append(OpsAction(
                id: "ops-restart",
                title: "Restart proxy",
                detail: reason,
                icon: "arrow.clockwise.circle",
                color: palette.critical,
                buttonTitle: "Retry",
                run: { await $0.restart() }))
        }
        return items
    }
}

private struct OpsAction: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let buttonTitle: String
    let run: (ProtectionController) async -> Void
}
