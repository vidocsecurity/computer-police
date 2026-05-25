import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SecurityStore?
    private var protection: ProtectionController?
    private var refreshLoop: RefreshLoop?
    private var eventStreamLoop: EventStreamLoop?
    private var notifier: Notifier?
    private var statusController: StatusItemController?
    private var didFinishLaunching = false
    private var visibleUISessionCount = 0

    func configure(
        store: SecurityStore,
        protection: ProtectionController,
        refreshLoop: RefreshLoop,
        eventStreamLoop: EventStreamLoop,
        notifier: Notifier)
    {
        AppLog.devLog("lifecycle", "AppDelegate configured")
        AppLog.lifecycle.info("AppDelegate configured")
        self.store = store
        self.protection = protection
        self.refreshLoop = refreshLoop
        self.eventStreamLoop = eventStreamLoop
        self.notifier = notifier
        startIfReady()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        AppLog.devLog("lifecycle", "Application did finish launching")
        AppLog.lifecycle.info("Application did finish launching")
        ProcessInfo.processInfo.disableAutomaticTermination("Computer Police is a menu bar agent")
        didFinishLaunching = true
        startIfReady()
    }

    private func startIfReady() {
        AppLog.lifecycle.debug("startIfReady called; didFinishLaunching=\(self.didFinishLaunching, privacy: .public), hasStatusController=\((self.statusController != nil), privacy: .public)")
        guard didFinishLaunching, statusController == nil else { return }
        guard let store, let protection, let notifier, refreshLoop != nil, eventStreamLoop != nil else {
            AppLog.devLog("lifecycle", "startIfReady waiting for dependencies")
            AppLog.lifecycle.debug("startIfReady waiting for dependencies")
            return
        }
        AppLog.devLog("lifecycle", "Starting app services")
        AppLog.lifecycle.info("Starting app services")
        notifier.requestAuthorization()
        let controller = StatusItemController(
            store: store,
            protection: protection,
            onOpen: { [weak self] in
                self?.beginVisibleUISession()
            },
            onClose: { [weak self] in
                self?.endVisibleUISession()
            })
        statusController = controller
        notifier.onTap = { [weak controller, weak store] tap in
            AppLog.devLog("notifications", "Notification tap received; eventID=\(tap.eventID ?? "-"), advisoryID=\(tap.advisoryID ?? "-")")
            AppLog.notifications.info("Notification tap received; eventID=\(tap.eventID ?? "-", privacy: .public), advisoryID=\(tap.advisoryID ?? "-", privacy: .public)")
            store?.focus(eventID: tap.eventID, advisoryID: tap.advisoryID)
            controller?.showPopover()
        }
        AppLog.devLog("lifecycle", "Starting protection monitoring")
        AppLog.lifecycle.info("Starting protection monitoring")
        protection.startMonitoring()
        AppLog.devLog("lifecycle", "Auto-enable check")
        AppLog.lifecycle.info("Auto-enable check")
        protection.autoEnableIfNeeded()
    }

    func beginVisibleUISession() {
        visibleUISessionCount += 1
        guard visibleUISessionCount == 1 else { return }
        AppLog.devLog("lifecycle", "Starting visible UI services")
        AppLog.lifecycle.info("Starting visible UI services")
        protection?.startLiveMonitoring()
        refreshLoop?.start()
        eventStreamLoop?.start()
    }

    func endVisibleUISession() {
        guard visibleUISessionCount > 0 else { return }
        visibleUISessionCount -= 1
        guard visibleUISessionCount == 0 else { return }
        AppLog.devLog("lifecycle", "Stopping visible UI services")
        AppLog.lifecycle.info("Stopping visible UI services")
        eventStreamLoop?.stop()
        refreshLoop?.stop()
        protection?.stopLiveMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification
        AppLog.devLog("lifecycle", "Application will terminate")
        AppLog.lifecycle.info("Application will terminate")
        eventStreamLoop?.stop()
        refreshLoop?.stop()
        protection?.applicationWillTerminate()
    }
}
