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
    private var isRefreshing = false

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
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            defer {
                Task { @MainActor in
                    self.isRefreshing = false
                }
            }
            do {
                let advisories = try? await client.advisories()
                let statsResult = try await client.stats(ifNoneMatch: etag)
                if let next = statsResult.etag {
                    etag = next
                }
                let events = try await client.events(limit: 100)
                await MainActor.run {
                    if let advisories {
                        store.advisoryStatus = advisories.malware
                    }
                    if let stats = statsResult.stats {
                        store.stats = stats
                    }
                    store.events = Self.mergedEvents(existing: store.events, fresh: events)
                    store.digest = WeeklyDigest.build(stats: store.stats, events: store.events, blocklist: blocklist)
                    notifier.notifyNewSecurityEvents(store.digest.vulnerableEvents, enabled: store.notificationsEnabled)
                }
            } catch {
                await MainActor.run {
                    store.lastError = error.localizedDescription
                }
            }
        }
    }

    private static func mergedEvents(existing: [PackageEvent], fresh: [PackageEvent]) -> [PackageEvent] {
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for event in fresh {
            byID[event.id] = event
        }
        return byID.values
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(200)
            .map { $0 }
    }
}
