import Foundation
import PackagePoliceCore
import UserNotifications

final class Notifier {
    private let center = UNUserNotificationCenter.current()
    private var notifiedEventIDs = Set<String>()
    private var lastProtectionNotification: String?

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyNewVulnerableEvents(_ events: [DigestEvent], enabled: Bool) {
        guard enabled else { return }
        for event in events where !notifiedEventIDs.contains(event.id) {
            notifiedEventIDs.insert(event.id)
            let title = "Vulnerable package detected"
            let body = "\(event.coordinate) matches \(event.blocklistEntry?.advisoryID ?? "the mock blocklist")."
            post(identifier: "package-\(event.id)", title: title, body: body)
        }
    }

    func notifyProtectionIssue(_ state: ProtectionState, enabled: Bool) {
        guard enabled else { return }
        let key: String
        let title: String
        switch state {
        case let .degraded(reason):
            key = "degraded:" + reason
            title = "Protection partial"
        case let .failed(reason):
            key = "failed:" + reason
            title = "Protection failed"
        default:
            return
        }
        guard lastProtectionNotification != key else { return }
        lastProtectionNotification = key
        post(identifier: "protection-\(key.hashValue)", title: title, body: state.detail)
    }

    private func post(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
}
