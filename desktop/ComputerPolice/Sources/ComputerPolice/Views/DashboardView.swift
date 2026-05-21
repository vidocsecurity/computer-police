import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController
    @State private var diagnosticsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitleStrip(subtitle: titleSubtitle)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    HeroPanel(store: store, protection: protection)
                    CaughtPosterView(store: store)
                    StatusPillView(store: store)
                    StatStripView(
                        scanned: store.digest.installsThisWeek,
                        clean: max(0, store.digest.installsThisWeek - store.digest.malwarePreventionCount),
                        caught: store.digest.malwarePreventionCount)
                    RecommendedActionsView(store: store, protection: protection)
                    PatrolLogView(events: store.digest.recentEvents, store: store)
                    if diagnosticsExpanded {
                        DiagnosticsView(store: store, protection: protection)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider().background(.black.opacity(0.2))

            HStack(spacing: 4) {
                Button(diagnosticsExpanded ? "Close case file" : "Open case file") {
                    withAnimation(.easeInOut(duration: 0.18)) { diagnosticsExpanded.toggle() }
                }
                .buttonStyle(BracketButtonStyle())
                Button("Department…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(BracketButtonStyle())
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(BracketButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .frame(width: Retro.Metrics.popoverWidth, height: Retro.Metrics.popoverHeight)
        .retroSurface()
    }

    private var titleSubtitle: String {
        switch store.protectionState {
        case .on: return "Patrol"
        case .off: return "Off duty"
        case .starting: return "Booting"
        case .stopping: return "Stand down"
        case .degraded: return "Backup needed"
        case .failed: return "Down"
        }
    }
}
