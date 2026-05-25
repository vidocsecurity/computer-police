import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: SecurityStore
    @ObservedObject var protection: ProtectionController
    let refreshLoop: RefreshLoop
    let onOpen: () -> Void
    let onClose: () -> Void

    @State private var section: Section = .patrol
    @State private var launchAtLogin = false
    @State private var didOpen = false

    enum Section: String, CaseIterable, Identifiable {
        case patrol, refresh, cli, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .patrol: return "Patrol"
            case .refresh: return "Refresh"
            case .cli: return "CLI"
            case .about: return "About"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitleStrip(subtitle: "Department")
            HStack(alignment: .top, spacing: 0) {
                sidebar
                    .frame(width: 130)
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 1)
                ScrollView {
                    pane
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 380)
        .retroSurface()
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            guard !didOpen else { return }
            didOpen = true
            onOpen()
        }
        .onDisappear {
            guard didOpen else { return }
            didOpen = false
            onClose()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Section.allCases) { item in
                sidebarRow(item)
            }
            Spacer()
        }
        .padding(8)
    }

    private func sidebarRow(_ item: Section) -> some View {
        Button {
            section = item
        } label: {
            HStack(spacing: 6) {
                Text(item == section ? "▸" : " ")
                    .font(.retroLabel)
                Text(item.title.uppercased())
                    .font(.retroLabel)
                    .tracking(0.8)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(item == section ? Color.black.opacity(0.06) : Color.clear)
            .overlay(BevelOverlay(style: item == section ? .sunken : .flat))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pane: some View {
        switch section {
        case .patrol: patrolPane
        case .refresh: refreshPane
        case .cli: cliPane
        case .about: aboutPane
        }
    }

    private var patrolPane: some View {
        BeveledPanel(style: .raised, padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Patrol Settings")
                Toggle("Auto-enable protection at launch", isOn: $store.autoEnableAtLaunch)
                    .toggleStyle(RetroCheckboxToggleStyle())
                Toggle("Keep proxy running when app quits", isOn: $store.keepProxyRunningOnQuit)
                    .toggleStyle(RetroCheckboxToggleStyle())
                Toggle("Launch Computer Police at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        updateLaunchAtLogin(newValue)
                    }))
                    .toggleStyle(RetroCheckboxToggleStyle())
                Toggle("Send notifications", isOn: $store.notificationsEnabled)
                    .toggleStyle(RetroCheckboxToggleStyle())
            }
        }
    }

    private var refreshPane: some View {
        BeveledPanel(style: .raised, padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Refresh Cadence")
                Text("How often Officer Mac polls the registry proxy for stats while the UI is open.")
                    .font(.retroBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("", selection: $store.refreshInterval) {
                    Text("15 seconds").tag(TimeInterval(15))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("5 minutes").tag(TimeInterval(300))
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: store.refreshInterval) { _, _ in
                    refreshLoop.restartTimer()
                }
            }
        }
    }

    private var cliPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeveledPanel(style: .raised, padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Custom Binary Path")
                    Text("Override the bundled `computer-police` binary if you keep one on PATH.")
                        .font(.retroBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("/usr/local/bin/computer-police", text: $store.userConfiguredBinaryPath)
                        .textFieldStyle(.plain)
                        .font(.retroData)
                        .padding(6)
                        .background(Color.white.opacity(0.001))
                        .overlay(BevelOverlay(style: .sunken))
                }
            }
            BeveledPanel(style: .raised, padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Service")
                    HStack(spacing: 8) {
                        Button("Install Bundled CLI") {
                            Task { await protection.installCLIForShell() }
                        }
                        .buttonStyle(BeveledButtonStyle(emphasis: .primary))
                        Button("Start") {
                            Task { await protection.enableProtection() }
                        }
                        .buttonStyle(BeveledButtonStyle())
                        Button("Stop") {
                            Task { await protection.disableProtection() }
                        }
                        .buttonStyle(BeveledButtonStyle())
                        Spacer()
                    }
                    Text("Installs `computer-police` to ~/.local/bin so your shell can find it.")
                        .font(.retroCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutPane: some View {
        BeveledPanel(style: .raised, padding: 12) {
            HStack(alignment: .top, spacing: 14) {
                OfficerView(expression: .patrol, size: 56)
                VStack(alignment: .leading, spacing: 6) {
                    Text("OFFICER MAC")
                        .font(.retroDisplay)
                        .tracking(1.2)
                    Text("Computer Police monitors local package installs through a loopback registry proxy.")
                        .font(.retroBody)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Malware prevention counts come from proxy-blocked OSV MAL advisories.")
                        .font(.retroCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text("Made by")
                            .font(.retroCaption)
                            .foregroundStyle(.secondary)
                        Link("Vidoc Security Lab", destination: URL(string: "https://www.vidocsecurity.com/")!)
                            .font(.retroCaption)
                    }
                    .padding(.top, 2)
                }
            }
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
