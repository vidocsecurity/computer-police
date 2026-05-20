import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController
    let refreshLoop: RefreshLoop
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Protection") {
                Toggle("Auto-enable protection at launch", isOn: $store.autoEnableAtLaunch)
                Toggle("Keep proxy running when app quits", isOn: $store.keepProxyRunningOnQuit)
                Toggle("Launch Package Police at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        updateLaunchAtLogin(newValue)
                    }))
                Toggle("Send notifications", isOn: $store.notificationsEnabled)
            }

            Section("Refresh") {
                Picker("Stats refresh cadence", selection: $store.refreshInterval) {
                    Text("15 seconds").tag(TimeInterval(15))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("5 minutes").tag(TimeInterval(300))
                }
                .onChange(of: store.refreshInterval) { _, _ in
                    refreshLoop.restartTimer()
                }
            }

            Section("CLI") {
                TextField("Custom package-police path", text: $store.userConfiguredBinaryPath)
                HStack {
                    Button("Install Bundled CLI to ~/.local/bin") {
                        Task { await protection.installCLIForShell() }
                    }
                    Button("Start") {
                        Task { await protection.enableProtection() }
                    }
                    Button("Stop") {
                        Task { await protection.disableProtection() }
                    }
                }
            }

            Section("About") {
                Text("Package Police monitors local package installs through a loopback registry proxy.")
                Text("Vulnerable/prevented counts are currently driven by the bundled mock blocklist.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            store.lastError = error.localizedDescription
        }
    }
}
