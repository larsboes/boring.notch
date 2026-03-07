//
//  PomodoroPlugin.swift
//  boringNotch
//
//  Built-in Pomodoro plugin wrapper.
//

import SwiftUI
import Combine
import Defaults

@MainActor
@Observable
final class PomodoroPlugin: NotchPlugin, ExportablePlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.pomodoro"
    
    let metadata = PluginMetadata(
        name: "Pomodoro Timer",
        description: "Focus sessions right from the notch",
        icon: "timer",
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    // Dedicated state
    let timer = PomodoroTimer()
    
    private(set) var state: PluginState = .inactive
    
    private var settings: PluginSettings?
    private var eventBus: PluginEventBus?
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        self.eventBus = context.eventBus
        state = .active
    }
    
    func deactivate() async {
        timer.stop()
        settings = nil
        eventBus = nil
        state = .inactive
        isEnabled = false
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        return AnyView(PomodoroClosedView(plugin: self))
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        return AnyView(PomodoroExpandedView(plugin: self))
    }
    
    func settingsContent() -> AnyView? {
        return AnyView(PomodoroSettingsView(plugin: self))
    }
    
    // MARK: - ExportablePlugin
    
    var supportedExportFormats: [ExportFormat] { [.json] }
    
    func exportData(format: ExportFormat) async throws -> Data {
        guard format == .json else {
            throw NSError(domain: "PomodoroPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported format"])
        }
        
        var export = [String: Any]()
        
        if let data = try? JSONEncoder().encode(timer.completedSessions),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            export["completedSessions"] = array
            
            // Stats summary for the JSON
            let workSessions = timer.completedSessions.filter { $0.type == .work }.count
            let totalWorkTime = timer.completedSessions.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
            
            export["stats"] = [
                "totalWorkSessions": workSessions,
                "totalWorkTimeMinutes": totalWorkTime / 60.0
            ]
        }
        
        return try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
    }
}
