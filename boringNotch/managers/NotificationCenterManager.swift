import Combine
import Defaults
import SwiftUI
import UserNotifications

class NotificationCenterManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterManager()

    @Published var notifications: [NotchNotification] = []
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        self.center.delegate = self
        self.loadNotifications()
        self.checkAuthorizationStatus()
        self.observeRetentionChanges()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
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
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
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
        Defaults[.storedNotifications] = notifications
    }

    private func loadNotifications() {
        self.notifications = Defaults[.storedNotifications]
        self.pruneExpiredNotifications()
    }

    private func pruneExpiredNotifications() {
        let retentionDays = Defaults[.notificationRetentionDays]
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        let originalCount = notifications.count
        notifications.removeAll { $0.date < cutoffDate }

        if notifications.count != originalCount {
            self.persist()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notifications
        if Defaults[.notificationDeliveryStyle] == .banner {
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
        if Defaults[.respectDoNotDisturb] && isFocusModeLikelyActive() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        
        if Defaults[.notificationSoundEnabled] {
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
        Defaults.publisher(.notificationRetentionDays)
            .sink { [weak self] _ in
                guard let self else { return }
                self.pruneExpiredNotifications()
                self.persist()
            }
            .store(in: &cancellables)
    }
}
