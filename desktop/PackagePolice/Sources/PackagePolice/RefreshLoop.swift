import Foundation
import PackagePoliceCore

@MainActor
final class RefreshLoop {
    private let store: SecurityStore
    private let client: APIClient
    private let blocklist: Blocklist
    private let notifier: Notifier
    private var timer: Timer?
    private var etag: String?

    init(store: SecurityStore, client: APIClient, blocklist: Blocklist, notifier: Notifier) {
        self.store = store
        self.client = client
        self.blocklist = blocklist
        self.notifier = notifier
    }

    func start() {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: store.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func restartTimer() {
        start()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task {
            do {
                let statsResult = try await client.stats(ifNoneMatch: etag)
                if let next = statsResult.etag {
                    etag = next
                }
                let events = try await client.events(limit: 100)
                await MainActor.run {
                    if let stats = statsResult.stats {
                        store.stats = stats
                    }
                    store.events = events
                    store.digest = WeeklyDigest.build(stats: store.stats, events: events, blocklist: blocklist)
                    notifier.notifyNewVulnerableEvents(store.digest.vulnerableEvents, enabled: store.notificationsEnabled)
                }
            } catch {
                await MainActor.run {
                    store.lastError = error.localizedDescription
                }
            }
        }
    }
}
