import Foundation
import PackagePoliceCore

enum ProtectionState: Equatable {
    case off
    case starting
    case on
    case degraded(String)
    case stopping
    case failed(String)

    var title: String {
        switch self {
        case .off: return "Off"
        case .starting: return "Starting..."
        case .on: return "On"
        case .degraded: return "Partial"
        case .stopping: return "Stopping..."
        case .failed: return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .off: return "Package installs are bypassing Computer Police."
        case .starting: return "Starting the local registry proxy."
        case .on: return "Registry traffic is flowing through Computer Police."
        case let .degraded(reason): return reason
        case .stopping: return "Restoring package-manager registry settings."
        case let .failed(reason): return reason
        }
    }

    var isEnabled: Bool {
        if case .on = self { return true }
        if case .degraded = self { return true }
        return false
    }
}

enum BinaryStatus: String {
    case missing = "Missing"
    case bundled = "Bundled"
    case path = "PATH"
    case configured = "Configured"
}

enum ProxyStatus: String {
    case stopped = "Stopped"
    case running = "Running"
    case unreachable = "Unreachable"
    case restarting = "Restarting"
}

enum RegistryStatus: String {
    case disabled = "Disabled"
    case enabled = "Enabled"
    case mismatch = "Mismatch"
}

@MainActor
final class SecurityStore: ObservableObject {
    @Published var protectionState: ProtectionState = .off
    @Published var binaryStatus: BinaryStatus = .missing
    @Published var proxyStatus: ProxyStatus = .stopped
    @Published var registryStatus: RegistryStatus = .disabled
    @Published var health: APIHealth?
    @Published var advisoryStatus: MalwareAdvisoryStatus?
    @Published var stats: APIStats = .empty
    @Published var events: [PackageEvent] = []
    @Published var digest: WeeklyDigest = WeeklyDigest.build(stats: .empty, events: [], blocklist: Blocklist(entries: []))
    @Published var malwareBlinkSignal: String?
    @Published var lastError: String?
    @Published var lastRestartAt: Date?
    @Published var lastChangedAt: Date = Date()
    /// When set, the patrol log will auto-expand the matching row and the
    /// hero/wanted panel can react. Cleared by views once they consume it.
    @Published var focusedEventID: String?
    /// When set, the WANTED panel auto-expands the matching recommendation.
    /// Set when a notification with an advisory ID is tapped.
    @Published var focusedAdvisoryID: String?
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    @Published var keepProxyRunningOnQuit: Bool {
        didSet { defaults.set(keepProxyRunningOnQuit, forKey: Keys.keepProxyRunningOnQuit) }
    }
    @Published var autoEnableAtLaunch: Bool {
        didSet { defaults.set(autoEnableAtLaunch, forKey: Keys.autoEnableAtLaunch) }
    }
    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }
    @Published var userConfiguredBinaryPath: String {
        didSet { defaults.set(userConfiguredBinaryPath, forKey: Keys.userConfiguredBinaryPath) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.keepProxyRunningOnQuit = defaults.object(forKey: Keys.keepProxyRunningOnQuit) as? Bool ?? false
        self.autoEnableAtLaunch = defaults.object(forKey: Keys.autoEnableAtLaunch) as? Bool ?? true
        self.refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval ?? 2
        self.userConfiguredBinaryPath = defaults.string(forKey: Keys.userConfiguredBinaryPath) ?? ""
    }

    func setProtectionState(_ state: ProtectionState) {
        protectionState = state
        lastChangedAt = Date()
    }

    func focus(eventID: String?, advisoryID: String?) {
        focusedEventID = eventID
        focusedAdvisoryID = advisoryID
    }

    func clearFocusedEvent(matching id: String) {
        if focusedEventID == id { focusedEventID = nil }
    }

    func clearFocusedAdvisory(matching id: String) {
        if focusedAdvisoryID == id { focusedAdvisoryID = nil }
    }
}

private enum Keys {
    static let notificationsEnabled = "notificationsEnabled"
    static let keepProxyRunningOnQuit = "keepProxyRunningOnQuit"
    static let autoEnableAtLaunch = "autoEnableAtLaunch"
    static let refreshInterval = "refreshInterval"
    static let userConfiguredBinaryPath = "userConfiguredBinaryPath"
}
