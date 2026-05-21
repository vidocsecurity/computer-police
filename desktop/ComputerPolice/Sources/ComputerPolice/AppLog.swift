import OSLog
import Foundation

enum AppLog {
    private static let subsystem = "dev.computerpolice.app"

    static let lifecycle = Logger(subsystem: subsystem, category: "app.lifecycle")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let statusItem = Logger(subsystem: subsystem, category: "statusItem")
    static let proxy = Logger(subsystem: subsystem, category: "proxy")
    static let refresh = Logger(subsystem: subsystem, category: "refresh")
    static let events = Logger(subsystem: subsystem, category: "events")

    static func devLog(_ category: String, _ message: String) {
        let line = "[ComputerPolice:\(category)] \(message)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
