import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SecurityStore?
    private var protection: ProtectionController?
    private var refreshLoop: RefreshLoop?
    private var notifier: Notifier?
    private var statusController: StatusItemController?

    func configure(
        store: SecurityStore,
        protection: ProtectionController,
        refreshLoop: RefreshLoop,
        notifier: Notifier)
    {
        self.store = store
        self.protection = protection
        self.refreshLoop = refreshLoop
        self.notifier = notifier
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        guard let store, let protection, let refreshLoop, let notifier else { return }
        notifier.requestAuthorization()
        statusController = StatusItemController(store: store, protection: protection)
        protection.startMonitoring()
        refreshLoop.start()
        protection.autoEnableIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification
        refreshLoop?.stop()
        protection?.applicationWillTerminate()
    }
}
