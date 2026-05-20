import PackagePoliceCore
import SwiftUI

struct RecentEventsView: View {
    let events: [DigestEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent activity")
                .font(.headline)
            if events.isEmpty {
                Text("No package installs observed yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func eventRow(_ event: DigestEvent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: event))
                .foregroundStyle(iconColor(for: event))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.coordinate)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(detail(for: event))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor(for: event), in: RoundedRectangle(cornerRadius: 8))
    }

    private func iconName(for event: DigestEvent) -> String {
        if event.isMalwarePrevented { return "shield.fill" }
        if event.isVulnerable { return "exclamationmark.triangle.fill" }
        return "shippingbox"
    }

    private func iconColor(for event: DigestEvent) -> Color {
        if event.isMalwarePrevented { return .red }
        if event.isVulnerable { return .orange }
        return .secondary
    }

    private func backgroundColor(for event: DigestEvent) -> Color {
        if event.isMalwarePrevented { return Color.red.opacity(0.12) }
        if event.isVulnerable { return Color.orange.opacity(0.12) }
        return Color.clear
    }

    private func detail(for event: DigestEvent) -> String {
        if let blockedBy = event.blockedBy {
            return "\(event.manager) • blocked by \(blockedBy) • HTTP \(event.statusCode)"
        }
        return "\(event.manager) • \(event.requestType) • HTTP \(event.statusCode)"
    }
}
