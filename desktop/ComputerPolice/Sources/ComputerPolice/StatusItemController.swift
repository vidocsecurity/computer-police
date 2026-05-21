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
    private let refresh: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var lastKnownScreenCount: Int
    private var pendingScreenChangePreviousCount: Int?
    private var screenChangeVisibilityTask: Task<Void, Never>?
    private var malwareBlinkTask: Task<Void, Never>?
    private var malwareBlinkDeadline: Date?
    private var malwareBlinkOn = true

    init(store: SecurityStore, protection: ProtectionController, refresh: @escaping () -> Void) {
        AppLog.devLog("statusItem", "Initializing status item controller")
        AppLog.statusItem.info("Initializing status item controller")
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

    private static func makeMenuBarShieldImage(showsAlert: Bool) -> NSImage {
        // Shield silhouette with an inset 5-point sheriff star punched out as
        // negative space. Drawn as a template image so macOS handles the tint
        // appropriately for light/dark menu bars. A small filled dot in the
        // top-right corner indicates an unacknowledged incident.
        let image = NSImage(size: NSSize(width: 21, height: 21), flipped: false) { rect in
            let shield = shieldPath(in: rect.insetBy(dx: 1.5, dy: 0.5))
            let starOuterRadius: CGFloat = 4.0
            let star = sheriffStarPath(
                center: NSPoint(x: rect.midX, y: rect.midY - 0.4),
                outerRadius: starOuterRadius,
                innerRadius: starOuterRadius * 0.42)

            let combined = NSBezierPath()
            combined.append(shield)
            combined.append(star.reversed)
            combined.windingRule = .evenOdd

            NSColor.black.setFill()
            combined.fill()

            if showsAlert {
                let dot = NSBezierPath(ovalIn: NSRect(
                    x: rect.maxX - 5.5,
                    y: rect.maxY - 5.5,
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

    private static func shieldPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let topY = rect.maxY
        let shoulderY = rect.maxY - rect.height * 0.15
        let waistY = rect.minY + rect.height * 0.45
        let pointY = rect.minY
        path.move(to: NSPoint(x: rect.minX, y: topY))
        path.line(to: NSPoint(x: rect.maxX, y: topY))
        path.line(to: NSPoint(x: rect.maxX, y: shoulderY))
        path.line(to: NSPoint(x: rect.maxX, y: waistY))
        path.curve(
            to: NSPoint(x: rect.midX, y: pointY),
            controlPoint1: NSPoint(x: rect.maxX, y: pointY + rect.height * 0.10),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.20, y: pointY))
        path.curve(
            to: NSPoint(x: rect.minX, y: waistY),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.20, y: pointY),
            controlPoint2: NSPoint(x: rect.minX, y: pointY + rect.height * 0.10))
        path.line(to: NSPoint(x: rect.minX, y: shoulderY))
        path.close()
        return path
    }

    private static func sheriffStarPath(
        center: NSPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat) -> NSBezierPath
    {
        let path = NSBezierPath()
        let points = 5
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y - CGFloat(sin(angle)) * radius
            if i == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        path.close()
        return path
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
        refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = Self.makeMenuBarShieldImage(showsAlert: malwareBlinkTask != nil)
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
