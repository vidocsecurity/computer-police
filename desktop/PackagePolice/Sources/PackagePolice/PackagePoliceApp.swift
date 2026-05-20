import AppKit
import SwiftUI
import PackagePoliceCore

@main
struct PackagePoliceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: SecurityStore
    @StateObject private var protection: ProtectionController
    private let refreshLoop: RefreshLoop

    init() {
        let store = SecurityStore()
        let client = APIClient()
        let blocklist = Blocklist.loadBundled()
        let notifier = Notifier()
        let protection = ProtectionController(store: store, client: client, notifier: notifier)
        let refreshLoop = RefreshLoop(store: store, client: client, blocklist: blocklist, notifier: notifier)
        _store = StateObject(wrappedValue: store)
        _protection = StateObject(wrappedValue: protection)
        self.refreshLoop = refreshLoop
        appDelegate.configure(store: store, protection: protection, refreshLoop: refreshLoop, notifier: notifier)
    }

    var body: some Scene {
        WindowGroup("PackagePoliceLifecycle") {
            HiddenWindowView()
        }
        .defaultSize(width: 20, height: 20)
        .windowStyle(.hiddenTitleBar)

        Settings {
            PreferencesView(store: store, protection: protection, refreshLoop: refreshLoop)
                .frame(width: 520, height: 420)
        }
    }
}

private struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onAppear {
                if let window = NSApp.windows.first(where: { $0.title == "PackagePoliceLifecycle" }) {
                    window.styleMask = [.borderless]
                    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                    window.isExcludedFromWindowsMenu = true
                    window.level = .floating
                    window.isOpaque = false
                    window.alphaValue = 0
                    window.backgroundColor = .clear
                    window.hasShadow = false
                    window.ignoresMouseEvents = true
                    window.canHide = false
                    window.setContentSize(NSSize(width: 1, height: 1))
                    window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                }
            }
    }
}
