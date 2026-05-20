import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController
    @State private var diagnosticsPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProtectionToggleView(store: store, protection: protection)
            StatusLightView(store: store)

            HStack(spacing: 10) {
                StatCardView(title: "Installs this week", value: "\(store.digest.installsThisWeek)", color: .blue)
                StatCardView(title: "Malware prevention", value: "\(store.digest.malwarePreventionCount)", color: store.digest.malwarePreventionCount > 0 ? .red : .green)
                StatCardView(title: "Blocked requests", value: "\(store.digest.preventedCount)", color: .purple)
            }

            RecommendedActionsView(store: store, protection: protection)
            RecentEventsView(events: store.digest.recentEvents)

            Divider()
            HStack {
                Button("Diagnostics...") { diagnosticsPresented.toggle() }
                Button("Preferences...") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(18)
        .frame(width: 420)
        .sheet(isPresented: $diagnosticsPresented) {
            DiagnosticsView(store: store, protection: protection)
                .frame(width: 460, height: 360)
        }
    }
}
