import Foundation
import ComputerPoliceCore

@MainActor
final class EventStreamLoop {
    private let store: SecurityStore
    private let client: APIClient
    private let blocklist: Blocklist
    private let notifier: Notifier
    private let refresh: @MainActor () -> Void
    private var task: Task<Void, Never>?

    init(
        store: SecurityStore,
        client: APIClient,
        blocklist: Blocklist,
        notifier: Notifier,
        refresh: @escaping @MainActor () -> Void)
    {
        self.store = store
        self.client = client
        self.blocklist = blocklist
        self.notifier = notifier
        self.refresh = refresh
    }

    func start() {
        stop()
        task = Task { [weak self] in
            await self?.listen()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func listen() async {
        while !Task.isCancelled {
            do {
                for try await event in client.eventStream() {
                    handle(event)
                }
            } catch {
                if !Task.isCancelled {
                    store.lastError = error.localizedDescription
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    private func handle(_ event: PackageEvent) {
        store.events = RefreshLoop.mergedEvents(existing: store.events, fresh: [event])
        store.digest = WeeklyDigest.build(stats: store.stats, events: store.events, blocklist: blocklist)
        notifier.notifyNewSecurityEvents(store.digest.vulnerableEvents, enabled: store.notificationsEnabled)
        if event.request.statusCode == 403, event.request.blockedBy != nil {
            store.malwareBlinkSignal = event.id
            refresh()
        }
    }
}
