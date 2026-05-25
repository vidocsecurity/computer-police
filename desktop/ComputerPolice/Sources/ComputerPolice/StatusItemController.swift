import AppKit
import Combine
import ComputerPoliceCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private let popover = NSPopover()
    private let store: SecurityStore
    private let protection: ProtectionController
    private let onOpen: () -> Void
    private let onClose: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var lastKnownScreenCount: Int
    private var pendingScreenChangePreviousCount: Int?
    private var screenChangeVisibilityTask: Task<Void, Never>?
    private var malwareBlinkTask: Task<Void, Never>?
    private var malwareBlinkDeadline: Date?
    private var malwareBlinkOn = true

    init(
        store: SecurityStore,
        protection: ProtectionController,
        onOpen: @escaping () -> Void,
        onClose: @escaping () -> Void)
    {
        AppLog.devLog("statusItem", "Initializing status item controller")
        AppLog.statusItem.info("Initializing status item controller")
        self.store = store
        self.protection = protection
        self.onOpen = onOpen
        self.onClose = onClose
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
        AppLog.devLog("statusItem", "Creating NSStatusItem")
        AppLog.statusItem.debug("Creating NSStatusItem")
        let item = statusBar.statusItem(withLength: 30)
        item.autosaveName = "dev.computerpolice.status-item"
        item.isVisible = true
        item.button?.imageScaling = .scaleProportionallyUpOrDown
        return item
    }

    private func configurePopover() {
        AppLog.devLog("statusItem", "Configuring popover \(Retro.Metrics.popoverWidth)x\(Retro.Metrics.popoverHeight)")
        AppLog.statusItem.debug("Configuring popover \(Retro.Metrics.popoverWidth, privacy: .public)x\(Retro.Metrics.popoverHeight, privacy: .public)")
        popover.behavior = .transient
        popover.contentSize = NSSize(
            width: Retro.Metrics.popoverWidth,
            height: Retro.Metrics.popoverHeight)
        popover.contentViewController = NSHostingController(rootView: DashboardView(store: store, protection: protection))
        popover.delegate = self
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            AppLog.devLog("statusItem", "Status item has no button during configureButton")
            AppLog.statusItem.error("Status item has no button during configureButton")
            return
        }
        button.imagePosition = .imageOnly
        button.title = ""
        button.action = #selector(togglePopover)
        button.target = self
        button.toolTip = "Computer Police"
        statusItem.isVisible = true
    }

    private static func makeMenuBarOfficerImage(showsAlert: Bool) -> NSImage {
        // A chibi compact Macintosh — same mascot as Officer Mac in the
        // popover — drawn as a template image so macOS tints it correctly
        // for light and dark menu bars. The case is filled; the CRT screen
        // and floppy slot are subtracted; the eyes and smile sit inside the
        // screen hole so the even/odd fill rule paints them back as solid
        // black, giving us a tiny face on the CRT. A small filled dot in the
        // top-right corner indicates an unacknowledged incident.
        let image = NSImage(size: NSSize(width: 21, height: 21), flipped: false) { rect in
            let combined = NSBezierPath()
            combined.windingRule = .evenOdd

            let body = NSBezierPath(
                roundedRect: NSRect(
                    x: rect.minX + 2,
                    y: rect.minY + 1.5,
                    width: 17,
                    height: 18),
                xRadius: 2,
                yRadius: 2)
            combined.append(body)

            let screen = NSRect(
                x: rect.minX + 4,
                y: rect.minY + 9,
                width: 13,
                height: 8)
            combined.append(NSBezierPath(rect: screen))

            let floppy = NSRect(
                x: rect.minX + 5.5,
                y: rect.minY + 5,
                width: 10,
                height: 1)
            combined.append(NSBezierPath(rect: floppy))

            let eyeY: CGFloat = rect.minY + 12.5
            let leftEye = NSBezierPath(ovalIn: NSRect(
                x: rect.minX + 7,
                y: eyeY,
                width: 2,
                height: 2))
            let rightEye = NSBezierPath(ovalIn: NSRect(
                x: rect.minX + 12,
                y: eyeY,
                width: 2,
                height: 2))
            combined.append(leftEye)
            combined.append(rightEye)

            // Short, flat smile. Susan Kare's happy Mac taught us a tiny
            // definite mouth reads better at icon scale than a thin curve.
            let smile = NSBezierPath(
                roundedRect: NSRect(
                    x: rect.minX + 9.0,
                    y: rect.minY + 10.3,
                    width: 3,
                    height: 1),
                xRadius: 0.5,
                yRadius: 0.5)
            combined.append(smile)

            NSColor.black.setFill()
            combined.fill()

            if showsAlert {
                let dot = NSBezierPath(ovalIn: NSRect(
                    x: rect.maxX - 5,
                    y: rect.maxY - 5,
                    width: 4,
                    height: 4))
                NSColor.black.setFill()
                dot.fill()
            }
            return true
        }
        image.isTemplate = true
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
        store.$malwareBlinkSignal
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.startMalwareBlink() }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            AppLog.devLog("statusItem", "Cannot toggle popover; status item button missing")
            AppLog.statusItem.error("Cannot toggle popover; status item button missing")
            return
        }
        if popover.isShown {
            AppLog.devLog("statusItem", "Closing popover from status item click")
            AppLog.statusItem.info("Closing popover from status item click")
            popover.performClose(nil)
        } else {
            AppLog.devLog("statusItem", "Opening popover from status item click")
            AppLog.statusItem.info("Opening popover from status item click")
            presentPopover(from: button)
        }
    }

    /// Opens the popover from anywhere, e.g. when a user taps a notification.
    /// Brings the app to the foreground so the popover stays anchored.
    func showPopover() {
        guard let button = statusItem.button else {
            AppLog.devLog("statusItem", "Cannot show popover; status item button missing")
            AppLog.statusItem.error("Cannot show popover; status item button missing")
            return
        }
        AppLog.devLog("statusItem", "Showing popover from external request")
        AppLog.statusItem.info("Showing popover from external request")
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            presentPopover(from: button)
        } else {
            AppLog.devLog("statusItem", "Popover already shown")
            AppLog.statusItem.debug("Popover already shown")
        }
    }

    private func presentPopover(from button: NSStatusBarButton) {
        AppLog.devLog("statusItem", "Presenting popover and refreshing state")
        AppLog.statusItem.debug("Presenting popover and refreshing state")
        stopMalwareBlink()
        onOpen()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = Self.makeMenuBarOfficerImage(showsAlert: malwareBlinkTask != nil)
        // Subtle dot pulse instead of recoloring the entire badge.
        button.alphaValue = malwareBlinkTask == nil || malwareBlinkOn ? 1.0 : 0.55
        button.toolTip = "Computer Police: \(store.protectionState.title)"
        statusItem.isVisible = true
    }

    private func startMalwareBlink() {
        AppLog.devLog("statusItem", "Starting malware alert badge pulse")
        AppLog.statusItem.info("Starting malware alert badge pulse")
        malwareBlinkDeadline = Date().addingTimeInterval(15)
        malwareBlinkOn = true
        updateIcon()
        guard malwareBlinkTask == nil else { return }
        malwareBlinkTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(450))
                } catch {
                    return
                }
                self?.tickMalwareBlink()
            }
        }
    }

    private func tickMalwareBlink() {
        guard let deadline = malwareBlinkDeadline, Date() < deadline else {
            stopMalwareBlink()
            return
        }
        malwareBlinkOn.toggle()
        updateIcon()
    }

    private func stopMalwareBlink() {
        if malwareBlinkTask != nil {
            AppLog.devLog("statusItem", "Stopping malware alert badge pulse")
            AppLog.statusItem.debug("Stopping malware alert badge pulse")
        }
        malwareBlinkTask?.cancel()
        malwareBlinkTask = nil
        malwareBlinkDeadline = nil
        malwareBlinkOn = true
        updateIcon()
    }

    private func recreateStatusItemForVisibilityRecovery(reason: String) {
        AppLog.devLog("statusItem", "Recreating status item for visibility recovery: \(reason)")
        AppLog.statusItem.warning("Recreating status item for visibility recovery: \(reason, privacy: .public)")
        NSLog("Computer Police menu bar item did not materialize (%@); recreating it", reason)
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
            NSLog("Computer Police menu bar item is still hidden after recreation: %@", recoveredSnapshot.description)
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

    deinit {
        malwareBlinkTask?.cancel()
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

extension StatusItemController: NSPopoverDelegate {
    nonisolated func popoverDidClose(_ notification: Notification) {
        _ = notification
        Task { @MainActor [weak self] in
            self?.onClose()
        }
    }
}

@MainActor
private enum MenuBarVisibilityGuidance {
    private static let guidanceShownKey = "computerPoliceMenuBarGuidanceShownAt"
    private static let guidanceRepeatInterval: TimeInterval = 24 * 60 * 60
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.MenuBarSettings")

    static func presentIfNeeded(defaults: UserDefaults = .standard, now: Date = Date()) {
        let lastShownAt = defaults.double(forKey: guidanceShownKey)
        guard lastShownAt == 0 || now.timeIntervalSince1970 - lastShownAt >= guidanceRepeatInterval else { return }
        defaults.set(now.timeIntervalSince1970, forKey: guidanceShownKey)

        let alert = NSAlert()
        alert.messageText = "Computer Police can't show its menu bar icon"
        alert.informativeText = "macOS is running Computer Police, but it may be hiding the icon in Menu Bar settings. Open Menu Bar settings and allow Computer Police in the menu bar."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "Dismiss")
        if alert.runModal() == .alertFirstButtonReturn, let settingsURL {
            NSWorkspace.shared.open(settingsURL)
        }
    }
}
