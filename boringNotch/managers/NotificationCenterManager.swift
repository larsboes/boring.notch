import Combine
import SwiftUI
import UserNotifications

@Observable
class NotificationCenterManager: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate {
    var notifications: [NotchNotification] = []
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private var settings: any NotificationSettings
    // Cached for nonisolated delegate callback
    nonisolated(unsafe) private var cachedDeliveryStyle: NotificationDeliveryStyle = .banner
    private var retentionObservation: Task<Void, Never>?

    init(settings: any NotificationSettings) {
        self.settings = settings
        self.cachedDeliveryStyle = settings.notificationDeliveryStyle
        super.init()
        self.center.delegate = self
        self.loadNotifications()
        self.checkAuthorizationStatus()
        self.observeRetentionChanges()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.checkAuthorizationStatus()
                if granted {
                    print("Notification permission granted")
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }

    func checkAuthorizationStatus() {
        center.getNotificationSettings { notifSettings in
            Task { @MainActor in
                self.authorizationStatus = notifSettings.authorizationStatus
            }
        }
    }

    func refreshAuthorizationStatus() {
        checkAuthorizationStatus()
    }

    func addNotification(_ notification: NotchNotification) {
        // Check for duplicates
        if !notifications.contains(where: { $0.id == notification.id }) {
            withAnimation {
                notifications.insert(notification, at: 0)
            }
            self.persist()
            self.scheduleSystemNotification(for: notification)
        }
    }

    func markAsRead(_ notification: NotchNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            withAnimation {
                notifications[index].isRead = true
            }
            self.persist()
        }
    }

    func markAllAsRead() {
        withAnimation {
            for i in 0..<notifications.count {
                notifications[i].isRead = true
            }
        }
        self.persist()
    }

    func removeNotification(_ notification: NotchNotification) {
        withAnimation {
            notifications.removeAll(where: { $0.id == notification.id })
        }
        self.persist()
    }

    func clearAll() {
        withAnimation {
            notifications.removeAll()
        }
        self.persist()
    }

    private func persist() {
        settings.storedNotifications = notifications
    }

    private func loadNotifications() {
        self.notifications = settings.storedNotifications
        self.pruneExpiredNotifications()
    }

    private func pruneExpiredNotifications() {
        let retentionDays = settings.notificationRetentionDays
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        let originalCount = notifications.count
        notifications.removeAll { $0.date < cutoffDate }

        if notifications.count != originalCount {
            self.persist()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notifications
        if cachedDeliveryStyle == .banner {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.sound])
        }
    }

    // MARK: - System Notification Scheduling

    private func scheduleSystemNotification(for notification: NotchNotification) {
        // Only schedule if we have permission and it's enabled
        guard authorizationStatus == .authorized else { return }

        // Check Do Not Disturb if respected
        if settings.respectDoNotDisturb && isFocusModeLikelyActive() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message

        if settings.notificationSoundEnabled {
            content.sound = .default
        }
        content.categoryIdentifier = notification.category.rawValue

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )

        self.center.add(request)
    }

    private func isFocusModeLikelyActive() -> Bool {
        let domain = "com.apple.ncprefs" as CFString
        if let enabled = CFPreferencesCopyAppValue("dndEnabled" as CFString, domain) as? Bool {
            return enabled
        }
        return false
    }

    private func observeRetentionChanges() {
        retentionObservation = Task { @MainActor [weak self] in
            var lastRetention = self?.settings.notificationRetentionDays ?? 7
            var lastDeliveryStyle = self?.settings.notificationDeliveryStyle ?? .banner
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self = self else { break }
                let currentRetention = self.settings.notificationRetentionDays
                if currentRetention != lastRetention {
                    lastRetention = currentRetention
                    self.pruneExpiredNotifications()
                    self.persist()
                }
                let currentDeliveryStyle = self.settings.notificationDeliveryStyle
                if currentDeliveryStyle != lastDeliveryStyle {
                    lastDeliveryStyle = currentDeliveryStyle
                    self.cachedDeliveryStyle = currentDeliveryStyle
                }
            }
        }
    }
}
