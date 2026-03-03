//
//  NotificationsPlugin.swift
//  boringNotch
//
//  Built-in notifications plugin.
//  Wraps NotificationCenterManager to provide notification history.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class NotificationsPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.notifications"
    
    let metadata = PluginMetadata(
        name: "Notifications",
        description: "View and manage notifications",
        icon: "bell.badge.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .system
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var notificationService: (any NotificationServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.notificationService = context.services.notifications
        self.settings = context.settings
        
        state = .active
    }
    
    func deactivate() async {
        notificationService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        return nil
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        // NotificationsView will be updated to use Environment(\.pluginManager)
        return AnyView(NotificationsView())
    }
    
    func settingsContent() -> AnyView? {
        AnyView(NotificationsSettingsView())
    }
}
