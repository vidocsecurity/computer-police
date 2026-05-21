import ComputerPoliceCore
import SwiftUI

/// The big front-of-popover panel: Officer Mac on the left, headline on the
/// right, and a dense single-line of facts plus a 7-day install sparkline.
/// The "caught" celebration moment lives in `CaughtPosterView` so the hero
/// panel stays a stable height across states.
struct HeroPanel: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController

    @Environment(\.retro) private var palette

    var body: some View {
        BeveledPanel(style: .sunken, padding: 10) {
            HStack(alignment: .top, spacing: 12) {
                OfficerView(expression: expression, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(headline)
                            .font(.retroDisplay)
                            .tracking(1.0)
                            .foregroundStyle(headlineColor)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Toggle("Protection", isOn: Binding(
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
                            .toggleStyle(RockerToggleStyle())
                            .labelsHidden()
                    }

                    Text(subhead)
                        .font(.retroBody)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .center, spacing: 8) {
                        Text(facts)
                            .font(.retroData)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 6)
                        Sparkline(values: sparklineValues, height: 14)
                            .frame(width: 64)
                    }
                    .padding(.top, 1)
                }
            }
        }
    }

    private var expression: OfficerExpression {
        if store.malwareBlinkSignal != nil { return .proud }
        switch store.protectionState {
        case .off: return .sleepy
        case .starting, .stopping: return .alert
        case .on: return .patrol
        case .degraded: return .concerned
        case .failed: return .hurt
        }
    }

    private var headline: String {
        switch store.protectionState {
        case .off: return "STAND DOWN"
        case .starting: return "STARTING…"
        case .stopping: return "STOPPING…"
        case .on: return "PATROL ACTIVE"
        case .degraded: return "NEEDS BACKUP"
        case .failed: return "OFFICER DOWN"
        }
    }

    private var headlineColor: Color {
        switch store.protectionState {
        case .on: return palette.accent
        case .degraded: return palette.warning
        case .failed: return palette.critical
        case .off: return palette.textSecondary
        case .starting, .stopping: return palette.textPrimary
        }
    }

    private var subhead: String {
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
        switch store.protectionState {
        case .off: return "Package installs are bypassing Officer Mac."
        case .on:
            if store.digest.malwarePreventionCount > 0 {
                return "On patrol. \(store.digest.malwarePreventionCount) caught this week."
            }
            return "On patrol. Quiet shift so far."
        case .starting: return "Starting the local registry proxy."
        case .stopping: return "Restoring package-manager registry settings."
        case let .degraded(reason): return reason
        case let .failed(reason): return reason
        }
    }

    private var facts: String {
        let installs = store.digest.installsThisWeek
        let caught = store.digest.malwarePreventionCount
        if let lastTime = lastEventTimeString {
            return "\(format(installs))·\(format(caught))·last \(lastTime)"
        }
        return "\(format(installs)) installs · \(format(caught)) caught"
    }

    private var lastEventTimeString: String? {
        guard let event = store.digest.recentEvents.first,
              let date = event.event.date
        else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func format(_ n: Int) -> String {
        String(format: "%04d", min(n, 9999))
    }

    private var sparklineValues: [Int] {
        var buckets = Array(repeating: 0, count: 7)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for event in store.digest.recentEvents {
            guard let date = event.event.date else { continue }
            let day = calendar.startOfDay(for: date)
            let diff = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            if diff >= 0 && diff < 7 {
                buckets[6 - diff] += 1
            }
        }
        let total = store.digest.installsThisWeek
        let summed = buckets.reduce(0, +)
        if summed == 0 && total > 0 {
            buckets[6] = total
        }
        return buckets
    }
}
