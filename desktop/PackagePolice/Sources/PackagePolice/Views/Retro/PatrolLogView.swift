import PackagePoliceCore
import SwiftUI

/// Replaces `RecentEventsView`. Zebra-striped log with grouped time buckets,
/// ecosystem badges, and a single accent column for status. HTTP status is
/// hidden by default; users can hover to reveal a tooltip.
struct PatrolLogView: View {
    let events: [DigestEvent]

    @Environment(\.retro) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SectionLabel(text: "Patrol Log")
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count)")
                        .font(.retroCaption)
                        .foregroundStyle(palette.textTertiary)
                }
            }

            BeveledPanel(style: .sunken, fillsBackground: true, padding: 0) {
                if events.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                            groupHeader(group.title)
                            ForEach(Array(group.events.enumerated()), id: \.offset) { idx, event in
                                eventRow(event, alt: idx.isMultiple(of: 2))
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            OfficerView(expression: .sleepy, size: 36, showsBadge: false)
            VStack(alignment: .leading, spacing: 1) {
                Text("No suspects today.")
                    .font(.retroBodyBold)
                    .foregroundStyle(palette.textPrimary)
                Text("Officer Mac will note any package install here.")
                    .font(.retroCaption)
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func groupHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.retroLabel)
                .tracking(0.8)
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(palette.panelDeep.opacity(0.55))
        .overlay(
            Rectangle()
                .fill(palette.bevelShadow.opacity(0.6))
                .frame(height: 1),
            alignment: .bottom)
    }

    private func eventRow(_ event: DigestEvent, alt: Bool) -> some View {
        HStack(spacing: 8) {
            Text(timeString(event))
                .font(.retroCaption)
                .foregroundStyle(palette.textSecondary)
                .frame(width: 38, alignment: .leading)
            EcosystemBadge(manager: event.manager)
            Text(event.coordinate)
                .font(.retroCaption)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            Text(statusText(for: event))
                .font(.retroLabel)
                .tracking(0.5)
                .foregroundStyle(statusColor(for: event))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(alt ? palette.stripeAlt : Color.clear)
        .help(tooltip(for: event))
    }

    private func timeString(_ event: DigestEvent) -> String {
        guard let date = event.event.date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func statusText(for event: DigestEvent) -> String {
        if event.isMalwarePrevented { return "CAUGHT" }
        if event.isVulnerable { return "REVIEW" }
        if event.statusCode >= 400 { return "BLOCK" }
        return "OK"
    }

    private func statusColor(for event: DigestEvent) -> Color {
        if event.isMalwarePrevented { return palette.warning }
        if event.isVulnerable { return palette.warning }
        if event.statusCode >= 500 { return palette.critical }
        if event.statusCode >= 400 { return palette.textSecondary }
        return palette.positive
    }

    private func tooltip(for event: DigestEvent) -> String {
        if let blockedBy = event.blockedBy {
            return "\(event.manager) · blocked by \(blockedBy) · HTTP \(event.statusCode)"
        }
        return "\(event.manager) · \(event.requestType) · HTTP \(event.statusCode)"
    }

    private var grouped: [(title: String, events: [DigestEvent])] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var todayEvents: [DigestEvent] = []
        var yesterdayEvents: [DigestEvent] = []
        var earlierEvents: [DigestEvent] = []

        for event in events {
            let date = event.event.date ?? now
            let day = calendar.startOfDay(for: date)
            if day >= today {
                todayEvents.append(event)
            } else if day >= yesterday {
                yesterdayEvents.append(event)
            } else {
                earlierEvents.append(event)
            }
        }

        var groups: [(title: String, events: [DigestEvent])] = []
        if !todayEvents.isEmpty { groups.append(("TODAY", todayEvents)) }
        if !yesterdayEvents.isEmpty { groups.append(("YESTERDAY", yesterdayEvents)) }
        if !earlierEvents.isEmpty { groups.append(("EARLIER", earlierEvents)) }
        return groups
    }
}

private struct EcosystemBadge: View {
    let manager: String

    @Environment(\.retro) private var palette

    var body: some View {
        Text(short.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.3)
            .foregroundStyle(palette.textPrimary)
            .frame(width: 30, height: 12)
            .background(color.opacity(0.22))
            .overlay(
                Rectangle()
                    .stroke(color.opacity(0.65), lineWidth: 1))
    }

    private var short: String {
        switch manager.lowercased() {
        case "npm": return "npm"
        case "bun": return "bun"
        case "yarn": return "yarn"
        case "pnpm": return "pnpm"
        default: return "?"
        }
    }

    private var color: Color {
        switch manager.lowercased() {
        case "npm": return Color(red: 0.80, green: 0.20, blue: 0.20)
        case "bun": return Color(red: 0.96, green: 0.74, blue: 0.36)
        case "yarn": return Color(red: 0.16, green: 0.40, blue: 0.78)
        case "pnpm": return Color(red: 0.96, green: 0.62, blue: 0.13)
        default: return palette.textTertiary
        }
    }
}
