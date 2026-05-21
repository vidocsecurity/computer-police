import Foundation
import ComputerPoliceCore
import UserNotifications

/// Context attached to a notification when it is posted, so a tap can take
/// the user straight to the relevant row in the popover.
struct NotificationTap: Sendable, Equatable {
    var eventID: String?
    var advisoryID: String?
}

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var notifiedEventIDs = Set<String>()
    private var lastProtectionNotification: String?

    /// Set by the AppDelegate on launch. Invoked when the user clicks/taps a
    /// notification that we posted. Always called on the main actor.
    var onTap: (@MainActor (NotificationTap) -> Void)?

    private enum UserInfoKey {
        static let eventID = "computer_police_event_id"
        static let advisoryID = "computer_police_advisory_id"
    }

    override init() {
        super.init()
        center.delegate = self
        AppLog.devLog("notifications", "Notifier initialized and delegate installed")
        AppLog.notifications.info("Notifier initialized and delegate installed")
    }

    func requestAuthorization() {
        AppLog.devLog("notifications", "Requesting notification authorization")
        AppLog.notifications.info("Requesting notification authorization")
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLog.devLog("notifications", "Notification authorization failed: \(error.localizedDescription)")
                AppLog.notifications.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                AppLog.devLog("notifications", "Notification authorization completed; granted=\(granted)")
                AppLog.notifications.info("Notification authorization completed; granted=\(granted, privacy: .public)")
            }
        }
    }

    func notifyNewSecurityEvents(_ events: [DigestEvent], enabled: Bool) {
        guard enabled else {
            AppLog.notifications.debug("Skipping security notifications because notifications are disabled")
            return
        }
        let pending = events.filter { !notifiedEventIDs.contains($0.id) }
        if !pending.isEmpty {
            AppLog.devLog("notifications", "Queueing \(pending.count) new security notification(s)")
            AppLog.notifications.info("Queueing \(pending.count, privacy: .public) new security notification(s)")
        }
        for event in pending {
            notifiedEventIDs.insert(event.id)
            let title = event.isMalwarePrevented ? "Malware install prevented" : "Risky package detected"
            let advisory = event.blockedBy ?? event.blocklistEntry?.advisoryID ?? "the local policy"
            let body = event.isMalwarePrevented
                ? "\(event.coordinate) was blocked by \(advisory)."
                : "\(event.coordinate) matches \(advisory)."
            var userInfo: [String: String] = [UserInfoKey.eventID: event.id]
            if let advisoryID = event.blockedBy ?? event.blocklistEntry?.advisoryID {
                userInfo[UserInfoKey.advisoryID] = advisoryID
            }
            post(
                identifier: "package-\(event.id)",
                title: title,
                body: body,
                userInfo: userInfo)
        }
    }

    func notifyProtectionIssue(_ state: ProtectionState, enabled: Bool) {
        guard enabled else {
            AppLog.notifications.debug("Skipping protection notification because notifications are disabled")
            return
        }
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
        post(
            identifier: "protection-\(key.hashValue)",
            title: title,
            body: state.detail,
            userInfo: [:])
    }

    private func post(
        identifier: String,
        title: String,
        body: String,
        userInfo: [String: String])
    {
        AppLog.notifications.info("Posting notification \(identifier, privacy: .public); title=\(title, privacy: .public)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
            if let error {
                AppLog.devLog("notifications", "Failed to post notification \(identifier): \(error.localizedDescription)")
                AppLog.notifications.error("Failed to post notification \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                AppLog.notifications.debug("Notification queued \(identifier, privacy: .public)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even when the app is in the foreground, so the user can
    /// click through to the matching row regardless of focus state.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        AppLog.devLog("notifications", "Notification will present: \(notification.request.identifier)")
        AppLog.notifications.debug("Notification will present: \(notification.request.identifier, privacy: .public)")
        completionHandler([.banner, .sound])
    }

    /// Notification was clicked. Activate the app and open the popover with
    /// the relevant row pre-expanded.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let userInfo = response.notification.request.content.userInfo
        let eventID = userInfo[UserInfoKey.eventID] as? String
        let advisoryID = userInfo[UserInfoKey.advisoryID] as? String
        AppLog.devLog("notifications", "Notification response received; identifier=\(response.notification.request.identifier), eventID=\(eventID ?? "-"), advisoryID=\(advisoryID ?? "-")")
        AppLog.notifications.info("Notification response received; identifier=\(response.notification.request.identifier, privacy: .public), eventID=\(eventID ?? "-", privacy: .public), advisoryID=\(advisoryID ?? "-", privacy: .public)")
        let tap = NotificationTap(eventID: eventID, advisoryID: advisoryID)
        // Hop to the main actor to invoke onTap, but call the system's
        // completion handler synchronously from the non-isolated context so
        // we don't risk crossing actor boundaries with it.
        Task { @MainActor [weak self] in
            self?.onTap?(tap)
        }
        completionHandler()
    }
}

extension Notifier: @unchecked Sendable {}
