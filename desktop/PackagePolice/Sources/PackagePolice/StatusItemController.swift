import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let store: SecurityStore
    private let protection: ProtectionController
    private var cancellables = Set<AnyCancellable>()

    init(store: SecurityStore, protection: ProtectionController) {
        self.store = store
        self.protection = protection
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configurePopover()
        configureButton()
        bindStore()
        updateIcon()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 620)
        popover.contentViewController = NSHostingController(rootView: DashboardView(store: store, protection: protection))
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Package Police")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self
        button.toolTip = "Package Police"
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.contentTintColor = iconColor
        button.toolTip = "Package Police: \(store.protectionState.title)"
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
}
