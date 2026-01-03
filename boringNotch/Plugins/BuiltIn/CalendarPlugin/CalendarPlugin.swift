//
//  CalendarPlugin.swift
//  boringNotch
//
//  Built-in calendar plugin.
//  Wraps CalendarService to provide events and reminders.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class CalendarPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.calendar"
    
    let metadata = PluginMetadata(
        name: "Calendar",
        description: "View upcoming events and reminders",
        icon: "calendar",
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var calendarService: (any CalendarServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.calendarService = context.services.calendar
        
        // Sync enabled state with legacy setting for now
        // In the future, this should be bi-directional or migrated
        if self.settings != nil {
            // We can read 'showCalendar' from global defaults or plugin settings
            // For now, let's assume the plugin is enabled by default in the manager,
            // but the view logic in NotchHomeView controls visibility.
        }
        
        state = .active
    }
    
    func deactivate() async {
        calendarService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        return nil
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        // CalendarView uses Environment(\.pluginManager) to access the service
        return AnyView(CalendarView())
    }
    
    func settingsContent() -> AnyView? {
        AnyView(CalendarSettings())
    }
}
