//
//  PluginManager+ViewHelpers.swift
//  boringNotch
//
//  Extracted view helpers and export support from PluginManager.
//

import SwiftUI

// MARK: - View Helpers

extension PluginManager {
    /// Plugins that show content in the expanded panel
    var panelPlugins: [AnyNotchPlugin] {
        activePlugins.filter { $0.hasExpandedPanelContent }
    }

    /// Get the view for a plugin's closed notch content
    @ViewBuilder
    func closedNotchView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasClosedNotchContent {
            switch id {
            case PluginID.music: if let p = plugin(id: id, as: MusicPlugin.self) { p.closedNotchContent() }
            case PluginID.shelf: if let p = plugin(id: id, as: ShelfPlugin.self) { p.closedNotchContent() }
            case PluginID.calendar: if let p = plugin(id: id, as: CalendarPlugin.self) { p.closedNotchContent() }
            case PluginID.weather: if let p = plugin(id: id, as: WeatherPlugin.self) { p.closedNotchContent() }
            case PluginID.battery: if let p = plugin(id: id, as: BatteryPlugin.self) { p.closedNotchContent() }
            case PluginID.webcam: if let p = plugin(id: id, as: WebcamPlugin.self) { p.closedNotchContent() }
            case PluginID.notifications: if let p = plugin(id: id, as: NotificationsPlugin.self) { p.closedNotchContent() }
            case PluginID.clipboard: if let p = plugin(id: id, as: ClipboardPlugin.self) { p.closedNotchContent() }
            case PluginID.habitTracker: if let p = plugin(id: id, as: HabitTrackerPlugin.self) { p.closedNotchContent() }
            case PluginID.pomodoro: if let p = plugin(id: id, as: PomodoroPlugin.self) { p.closedNotchContent() }
            case PluginID.teleprompter: if let p = plugin(id: id, as: TeleprompterPlugin.self) { p.closedNotchContent() }
            case PluginID.displaySurface: if let p = plugin(id: id, as: DisplaySurfacePlugin.self) { p.closedNotchContent() }
            default: EmptyView()
            }
        }
    }

    /// Get the view for a plugin's expanded panel content
    @ViewBuilder
    func expandedPanelView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasExpandedPanelContent {
            switch id {
            case PluginID.music: if let p = plugin(id: id, as: MusicPlugin.self) { p.expandedPanelContent() }
            case PluginID.shelf: if let p = plugin(id: id, as: ShelfPlugin.self) { p.expandedPanelContent() }
            case PluginID.calendar: if let p = plugin(id: id, as: CalendarPlugin.self) { p.expandedPanelContent() }
            case PluginID.weather: if let p = plugin(id: id, as: WeatherPlugin.self) { p.expandedPanelContent() }
            case PluginID.battery: if let p = plugin(id: id, as: BatteryPlugin.self) { p.expandedPanelContent() }
            case PluginID.webcam: if let p = plugin(id: id, as: WebcamPlugin.self) { p.expandedPanelContent() }
            case PluginID.notifications: if let p = plugin(id: id, as: NotificationsPlugin.self) { p.expandedPanelContent() }
            case PluginID.clipboard: if let p = plugin(id: id, as: ClipboardPlugin.self) { p.expandedPanelContent() }
            case PluginID.habitTracker: if let p = plugin(id: id, as: HabitTrackerPlugin.self) { p.expandedPanelContent() }
            case PluginID.pomodoro: if let p = plugin(id: id, as: PomodoroPlugin.self) { p.expandedPanelContent() }
            case PluginID.teleprompter: if let p = plugin(id: id, as: TeleprompterPlugin.self) { p.expandedPanelContent() }
            case PluginID.displaySurface: if let p = plugin(id: id, as: DisplaySurfacePlugin.self) { p.expandedPanelContent() }
            default: EmptyView()
            }
        }
    }

    /// Get the view for a plugin's settings content
    @ViewBuilder
    func settingsView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.hasSettingsContent {
            switch id {
            case PluginID.music: if let p = plugin(id: id, as: MusicPlugin.self) { p.settingsContent() }
            case PluginID.shelf: if let p = plugin(id: id, as: ShelfPlugin.self) { p.settingsContent() }
            case PluginID.calendar: if let p = plugin(id: id, as: CalendarPlugin.self) { p.settingsContent() }
            case PluginID.weather: if let p = plugin(id: id, as: WeatherPlugin.self) { p.settingsContent() }
            case PluginID.battery: if let p = plugin(id: id, as: BatteryPlugin.self) { p.settingsContent() }
            case PluginID.webcam: if let p = plugin(id: id, as: WebcamPlugin.self) { p.settingsContent() }
            case PluginID.notifications: if let p = plugin(id: id, as: NotificationsPlugin.self) { p.settingsContent() }
            case PluginID.clipboard: if let p = plugin(id: id, as: ClipboardPlugin.self) { p.settingsContent() }
            case PluginID.habitTracker: if let p = plugin(id: id, as: HabitTrackerPlugin.self) { p.settingsContent() }
            case PluginID.pomodoro: if let p = plugin(id: id, as: PomodoroPlugin.self) { p.settingsContent() }
            case PluginID.teleprompter: if let p = plugin(id: id, as: TeleprompterPlugin.self) { p.settingsContent() }
            case PluginID.displaySurface: if let p = plugin(id: id, as: DisplaySurfacePlugin.self) { p.settingsContent() }
            default: EmptyView()
            }
        }
    }
}

// MARK: - Export Support

extension PluginManager {
    /// Get all exportable plugins
    var exportablePlugins: [AnyNotchPlugin] {
        return activePlugins
    }

    /// Export data from a specific plugin
    func exportPluginData(id: String, format: ExportFormat) async throws -> Data {
        guard let plugin = plugin(id: id) else {
            throw PluginError.notFound(id)
        }

        guard plugin.state.isActive else {
            throw PluginError.invalidState("Plugin not active")
        }

        throw PluginError.exportFailed("Export not implemented for this plugin")
    }

    /// Export data from all exportable plugins
    func exportAllPluginData(format: ExportFormat) async throws -> [String: Data] {
        var results: [String: Data] = [:]

        for plugin in exportablePlugins {
            do {
                let data = try await exportPluginData(id: plugin.id, format: format)
                results[plugin.id] = data
            } catch {
                print("Failed to export \(plugin.id): \(error)")
            }
        }

        return results
    }
}

// MARK: - Environment Key

private struct PluginManagerKey: EnvironmentKey {
    static let defaultValue: PluginManager? = nil
}

extension EnvironmentValues {
    var pluginManager: PluginManager? {
        get { self[PluginManagerKey.self] }
        set { self[PluginManagerKey.self] = newValue }
    }
}

// MARK: - Preview Support

#if DEBUG
extension PluginManager {
    /// Create a preview manager with mock services
    static func preview() -> PluginManager {
        fatalError("Preview not implemented - needs mock services")
    }
}
#endif
