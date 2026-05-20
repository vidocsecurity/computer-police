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
                ForEach(events) { event in
                    HStack(spacing: 8) {
                        Image(systemName: event.isVulnerable ? "exclamationmark.triangle.fill" : "shippingbox")
                            .foregroundStyle(event.isVulnerable ? .orange : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.coordinate)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text("\(event.manager) • \(event.requestType) • HTTP \(event.statusCode)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(event.isVulnerable ? Color.orange.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
