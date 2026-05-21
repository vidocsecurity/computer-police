import Foundation

@MainActor
final class Watchdog {
    private var consecutiveFailures = 0
    private var restartAttempts: [Date] = []

    func recordSuccess() {
        consecutiveFailures = 0
    }

    func recordFailure() -> Bool {
        consecutiveFailures += 1
        return consecutiveFailures >= 3
    }

    func canRestart(now: Date = Date()) -> Bool {
        restartAttempts = restartAttempts.filter { now.timeIntervalSince($0) < 60 }
        return restartAttempts.count < 3
    }

    func recordRestart(now: Date = Date()) -> TimeInterval {
        restartAttempts.append(now)
        consecutiveFailures = 0
        switch restartAttempts.count {
        case 1: return 1
        case 2: return 2
        case 3: return 4
        default: return 30
        }
    }
}
