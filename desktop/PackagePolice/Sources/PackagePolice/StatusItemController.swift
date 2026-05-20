import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private let popover = NSPopover()
    private let store: SecurityStore
    private let protection: ProtectionController
    private let refresh: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var lastKnownScreenCount: Int
    private var pendingScreenChangePreviousCount: Int?
    private var screenChangeVisibilityTask: Task<Void, Never>?

    init(store: SecurityStore, protection: ProtectionController, refresh: @escaping () -> Void) {
        self.store = store
        self.protection = protection
        self.refresh = refresh
        self.statusBar = .system
        self.statusItem = Self.makeStatusItem(statusBar: statusBar)
        self.lastKnownScreenCount = NSScreen.screens.count
        super.init()
        configurePopover()
        configureButton()
        bindStore()
        updateIcon()
        scheduleStartupStatusItemVisibilityCheck()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    private static func makeStatusItem(statusBar: NSStatusBar) -> NSStatusItem {
        let item = statusBar.statusItem(withLength: 30)
        item.autosaveName = "dev.packagepolice.status-item"
        item.isVisible = true
        item.button?.imageScaling = .scaleProportionallyUpOrDown
        return item
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 620)
        popover.contentViewController = NSHostingController(rootView: DashboardView(store: store, protection: protection))
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.makeMenuBarShieldImage()
        button.imagePosition = .imageOnly
        button.title = ""
        button.action = #selector(togglePopover)
        button.target = self
        button.toolTip = "Package Police"
        statusItem.isVisible = true
    }

    private static func makeMenuBarShieldImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 21, height: 21), flipped: false) { rect in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.midX, y: rect.maxY - 1.5))
            path.curve(
                to: NSPoint(x: rect.maxX - 2.5, y: rect.maxY - 5.5),
                controlPoint1: NSPoint(x: rect.midX + 3.2, y: rect.maxY - 2.0),
                controlPoint2: NSPoint(x: rect.maxX - 4.2, y: rect.maxY - 3.3))
            path.line(to: NSPoint(x: rect.maxX - 3.5, y: rect.midY - 1.0))
            path.curve(
                to: NSPoint(x: rect.midX, y: rect.minY + 1.5),
                controlPoint1: NSPoint(x: rect.maxX - 4.0, y: rect.minY + 5.5),
                controlPoint2: NSPoint(x: rect.midX + 1.5, y: rect.minY + 2.5))
            path.curve(
                to: NSPoint(x: rect.minX + 3.5, y: rect.midY - 1.0),
                controlPoint1: NSPoint(x: rect.midX - 1.5, y: rect.minY + 2.5),
                controlPoint2: NSPoint(x: rect.minX + 4.0, y: rect.minY + 5.5))
            path.line(to: NSPoint(x: rect.minX + 2.5, y: rect.maxY - 5.5))
            path.curve(
                to: NSPoint(x: rect.midX, y: rect.maxY - 1.5),
                controlPoint1: NSPoint(x: rect.minX + 4.2, y: rect.maxY - 3.3),
                controlPoint2: NSPoint(x: rect.midX - 3.2, y: rect.maxY - 2.0))
            path.close()
            NSColor.white.setFill()
            path.fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func bindStore() {
        store.$protectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
        store.$digest
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        if button.image == nil {
            button.image = Self.makeMenuBarShieldImage()
        }
        button.toolTip = "Package Police: \(store.protectionState.title)"
        statusItem.isVisible = true
    }

    private func recreateStatusItemForVisibilityRecovery(reason: String) {
        NSLog("Package Police menu bar item did not materialize (%@); recreating it", reason)
        statusItem.menu = nil
        statusBar.removeStatusItem(statusItem)
        statusItem = Self.makeStatusItem(statusBar: statusBar)
        configureButton()
        updateIcon()
    }

    private func scheduleStartupStatusItemVisibilityCheck(appLaunchedAt: Date = Date()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            Task { @MainActor [weak self] in
                self?.checkStartupStatusItemVisibility(appLaunchedAt: appLaunchedAt)
            }
        }
    }

    private func checkStartupStatusItemVisibility(appLaunchedAt: Date, now: Date = Date()) {
        let snapshot = StatusItemVisibilitySnapshot(statusItem)
        guard now.timeIntervalSince(appLaunchedAt) <= 10, snapshot.shouldRecover else { return }
        recreateStatusItemForVisibilityRecovery(reason: "startup snapshot: \(snapshot)")

        let recoveredSnapshot = StatusItemVisibilitySnapshot(statusItem)
        if recoveredSnapshot.shouldRecover {
            NSLog("Package Police menu bar item is still hidden after recreation: %@", recoveredSnapshot.description)
            MenuBarVisibilityGuidance.presentIfNeeded()
        }
    }

    @objc private func handleScreenParametersDidChange(_ notification: Notification) {
        _ = notification
        let previousScreenCount = max(pendingScreenChangePreviousCount ?? lastKnownScreenCount, lastKnownScreenCount)
        let currentScreenCount = NSScreen.screens.count
        pendingScreenChangePreviousCount = previousScreenCount
        lastKnownScreenCount = currentScreenCount
        scheduleScreenChangeStatusItemVisibilityCheck(
            previousScreenCount: previousScreenCount,
            currentScreenCount: currentScreenCount)
    }

    private func scheduleScreenChangeStatusItemVisibilityCheck(
        previousScreenCount: Int,
        currentScreenCount: Int)
    {
        screenChangeVisibilityTask?.cancel()
        screenChangeVisibilityTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(750))
            } catch {
                return
            }
            self?.checkScreenChangeStatusItemVisibility(
                previousScreenCount: previousScreenCount,
                currentScreenCount: currentScreenCount)
        }
    }

    private func checkScreenChangeStatusItemVisibility(previousScreenCount: Int, currentScreenCount: Int) {
        pendingScreenChangePreviousCount = nil
        let snapshot = StatusItemVisibilitySnapshot(statusItem)
        let lostScreen = currentScreenCount < previousScreenCount && snapshot.isVisible
        guard snapshot.shouldRecover || lostScreen else { return }
        recreateStatusItemForVisibilityRecovery(reason: "screen change snapshot: \(snapshot)")
    }

    private var iconColor: NSColor {
        switch store.protectionState {
        case .on:
            return store.digest.vulnerableCount > 0 ? .systemOrange : .systemGreen
        case .degraded, .starting, .stopping:
            return .systemYellow
        case .failed:
            return .systemRed
        case .off:
            return .secondaryLabelColor
        }
    }

    deinit {
        screenChangeVisibilityTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}

private struct StatusItemVisibilitySnapshot: CustomStringConvertible {
    let isVisible: Bool
    let hasButton: Bool
    let hasWindow: Bool
    let hasScreen: Bool
    let isOnCurrentScreen: Bool
    let buttonWidth: CGFloat

    @MainActor
    init(_ item: NSStatusItem) {
        let screen = item.button?.window?.screen
        self.isVisible = item.isVisible
        self.hasButton = item.button != nil
        self.hasWindow = item.button?.window != nil
        self.hasScreen = screen != nil
        self.isOnCurrentScreen = screen.map(Self.isCurrentScreen) ?? false
        self.buttonWidth = item.button?.frame.size.width ?? 0
    }

    var shouldRecover: Bool {
        guard isVisible else { return false }
        guard hasButton else { return true }
        return !hasWindow || !hasScreen || !isOnCurrentScreen || buttonWidth <= 0
    }

    var description: String {
        "visible=\(isVisible),button=\(hasButton),window=\(hasWindow),screen=\(hasScreen),currentScreen=\(isOnCurrentScreen),width=\(String(format: "%.1f", Double(buttonWidth)))"
    }

    @MainActor
    private static func isCurrentScreen(_ screen: NSScreen) -> Bool {
        let screenNumber = self.screenNumber(screen)
        return NSScreen.screens.contains { candidate in
            if let screenNumber, let candidateNumber = self.screenNumber(candidate) {
                return candidateNumber == screenNumber
            }
            return candidate === screen
        }
    }

    private static func screenNumber(_ screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }
}

@MainActor
private enum MenuBarVisibilityGuidance {
    private static let guidanceShownKey = "packagePoliceMenuBarGuidanceShownAt"
    private static let guidanceRepeatInterval: TimeInterval = 24 * 60 * 60
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.MenuBarSettings")

    static func presentIfNeeded(defaults: UserDefaults = .standard, now: Date = Date()) {
        let lastShownAt = defaults.double(forKey: guidanceShownKey)
        guard lastShownAt == 0 || now.timeIntervalSince1970 - lastShownAt >= guidanceRepeatInterval else { return }
        defaults.set(now.timeIntervalSince1970, forKey: guidanceShownKey)

        let alert = NSAlert()
        alert.messageText = "Package Police can't show its menu bar icon"
        alert.informativeText = "macOS is running Package Police, but it may be hiding the icon in Menu Bar settings. Open Menu Bar settings and allow Package Police in the menu bar."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "Dismiss")
        if alert.runModal() == .alertFirstButtonReturn, let settingsURL {
            NSWorkspace.shared.open(settingsURL)
        }
    }
}
