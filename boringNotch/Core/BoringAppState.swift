import SwiftUI
import Combine

/// Concrete implementation of AppStateProviding
@MainActor
@Observable
final class BoringAppState: AppStateProviding {
    var isScreenLocked: Bool = false

    /// Use nonisolated(unsafe) to allow cleanup in deinit
    /// This is safe because we only access it to remove observers
    nonisolated(unsafe) private var observers: [Any] = []

    init() {
        setupObservers()
    }

    deinit {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    private func setupObservers() {
        let center = DistributedNotificationCenter.default()

        observers.append(center.addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenLocked = true
        })

        observers.append(center.addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenLocked = false
        })
    }
}
