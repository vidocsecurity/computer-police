import Foundation
import ComputerPoliceCore

@MainActor
final class Heartbeat {
    private let client: APIClient
    private var timer: Timer?

    var onResult: ((Result<APIHealth, Error>) -> Void)?

    init(client: APIClient) {
        self.client = client
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.beat()
            }
        }
        beat()
    }

    func refreshOnce() {
        beat()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func beat() {
        let client = client
        Task { [weak self, client] in
            do {
                let health = try await client.health()
                await MainActor.run { self?.onResult?(.success(health)) }
            } catch {
                await MainActor.run { self?.onResult?(.failure(error)) }
            }
        }
    }
}
