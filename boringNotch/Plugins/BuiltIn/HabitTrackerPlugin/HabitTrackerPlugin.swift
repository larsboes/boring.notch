//
//  HabitTrackerPlugin.swift
//  boringNotch
//
//  Built-in habit tracking plugin.
//

import SwiftUI
import Combine
import Defaults

@MainActor
@Observable
final class HabitTrackerPlugin: NotchPlugin, ExportablePlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.habittracker"
    
    let metadata = PluginMetadata(
        name: "Habit Tracker",
        description: "Track your daily habits directly from the notch",
        icon: "checkmark.circle.fill", // Changed from checkmark.seal to checkmark.circle.fill which is standard
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    // Provide a dedicated data store
    let store = HabitStore()
    
    private(set) var state: PluginState = .inactive
    
    private var settings: PluginSettings?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        state = .active
    }
    
    func deactivate() async {
        cancellables.removeAll()
        settings = nil
        state = .inactive
        isEnabled = false
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        // To be implemented: dots for today's habits
        return AnyView(HabitClosedView(plugin: self))
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        // To be implemented: list of habits to tick off
        return AnyView(HabitExpandedView(plugin: self))
    }
    
    func settingsContent() -> AnyView? {
        // We always show settings so users can turn it on/off
        return AnyView(HabitSettingsView(plugin: self))
    }
    
    // MARK: - ExportablePlugin
    
    var supportedExportFormats: [ExportFormat] { [.json] }
    
    func exportData(format: ExportFormat) async throws -> Data {
        guard format == .json else {
            throw NSError(domain: "HabitTrackerPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported format"])
        }
        
        var export = [String: Any]()
        
        // Serialize habits
        if let habitData = try? JSONEncoder().encode(store.habits),
           let habitArray = try? JSONSerialization.jsonObject(with: habitData) as? [[String: Any]] {
            export["habits"] = habitArray
        }
        
        // Serialize completions
        if let completionData = try? JSONEncoder().encode(store.completions),
           let completionArray = try? JSONSerialization.jsonObject(with: completionData) as? [[String: Any]] {
            export["completions"] = completionArray
        }
        
        return try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
    }
}
