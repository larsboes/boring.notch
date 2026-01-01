//
//  PluginManager.swift
//  boringNotch
//
//  Central registry and lifecycle manager for all plugins.
//

import SwiftUI
import Combine

// MARK: - Plugin Manager

/// Central registry for all plugins.
/// Manages plugin lifecycle, provides access to plugins for views,
/// and handles inter-plugin communication.
@MainActor
@Observable
final class PluginManager {
    // MARK: - Properties

    /// All registered plugins (enabled and disabled)
    private var plugins: [String: AnyNotchPlugin] = [:]

    /// Plugin activation order
    private var pluginOrder: [String] = []

    /// Service container for dependency injection
    let services: ServiceContainer

    /// Event bus for inter-plugin communication
    let eventBus: PluginEventBus

    /// App state provider
    private let appState: AppStateProviding

    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// All registered plugin IDs
    var allPluginIds: [String] {
        pluginOrder
    }

    /// All active (enabled and activated) plugins
    var activePlugins: [AnyNotchPlugin] {
        pluginOrder
            .compactMap { plugins[$0] }
            .filter { $0.isEnabled && $0.state.isActive }
    }

    /// All enabled plugins (may still be activating)
    var enabledPlugins: [AnyNotchPlugin] {
        pluginOrder
            .compactMap { plugins[$0] }
            .filter { $0.isEnabled }
    }

    /// Plugins that show content in the expanded panel
    var panelPlugins: [AnyNotchPlugin] {
        activePlugins.filter { $0.expandedPanelContent() != nil }
    }

    // MARK: - Initialization

    init(
        services: ServiceContainer,
        eventBus: PluginEventBus,
        appState: AppStateProviding,
        builtInPlugins: [any NotchPlugin] = []
    ) {
        self.services = services
        self.eventBus = eventBus
        self.appState = appState

        // Register built-in plugins
        for plugin in builtInPlugins {
            registerPlugin(plugin)
        }
    }

    // MARK: - Plugin Registration

    /// Register a plugin with the manager
    func registerPlugin(_ plugin: any NotchPlugin) {
        let wrapped = AnyNotchPlugin(plugin)
        plugins[plugin.id] = wrapped
        pluginOrder.append(plugin.id)
    }

    /// Unregister a plugin
    func unregisterPlugin(id: String) async {
        guard let plugin = plugins[id] else { return }

        // Deactivate if active
        if plugin.state.isActive {
            await plugin.deactivate()
        }

        plugins.removeValue(forKey: id)
        pluginOrder.removeAll { $0 == id }
    }

    // MARK: - Plugin Lifecycle

    /// Enable and activate a plugin
    func enablePlugin(_ id: String) async throws {
        guard let plugin = plugins[id] else {
            throw PluginError.notFound(id)
        }

        guard !plugin.state.isActive else { return }

        let context = PluginContext(
            settings: PluginSettings(pluginId: id),
            services: services,
            eventBus: eventBus,
            appState: appState
        )

        do {
            try await plugin.activate(context: context)
            plugin.isEnabled = true
            eventBus.emit(.pluginActivated, from: id)
        } catch {
            throw PluginError.activationFailed(error.localizedDescription)
        }
    }

    /// Disable and deactivate a plugin
    func disablePlugin(_ id: String) async {
        guard let plugin = plugins[id] else { return }

        await plugin.deactivate()
        plugin.isEnabled = false
        eventBus.emit(.pluginDeactivated, from: id)
    }

    /// Toggle plugin enabled state
    func togglePlugin(_ id: String) async throws {
        guard let plugin = plugins[id] else {
            throw PluginError.notFound(id)
        }

        if plugin.isEnabled {
            await disablePlugin(id)
        } else {
            try await enablePlugin(id)
        }
    }

    /// Activate all enabled plugins (call on app launch)
    func activateEnabledPlugins() async {
        for id in pluginOrder {
            guard let plugin = plugins[id], plugin.isEnabled else { continue }

            do {
                try await enablePlugin(id)
            } catch {
                print("Failed to activate plugin \(id): \(error)")
            }
        }
    }

    /// Deactivate all plugins (call on app termination)
    func deactivateAllPlugins() async {
        for id in pluginOrder {
            await disablePlugin(id)
        }
    }

    // MARK: - Plugin Access

    /// Get a plugin by ID
    func plugin(id: String) -> AnyNotchPlugin? {
        plugins[id]
    }

    /// Get a plugin by ID with specific type
    func plugin<T: NotchPlugin>(id: String, as type: T.Type) -> T? {
        plugins[id] as? T
    }

    /// Check if a plugin is registered
    func hasPlugin(id: String) -> Bool {
        plugins[id] != nil
    }

    /// Check if a plugin is enabled
    func isPluginEnabled(id: String) -> Bool {
        plugins[id]?.isEnabled ?? false
    }

    // MARK: - Positioned Plugins

    /// Get plugins at a specific closed notch position
    func plugins(at position: ClosedNotchPosition) -> [AnyNotchPlugin] {
        activePlugins.filter { plugin in
            // Check if plugin conforms to PositionedPlugin via the wrapped plugin
            // For now, we'll use a simple check based on plugin ID
            switch position {
            case .left:
                return false // No built-in left plugins yet
            case .center:
                return plugin.id == "com.boringnotch.music"
            case .right:
                return plugin.id == "com.boringnotch.weather"
            case .farRight:
                return plugin.id == "com.boringnotch.battery"
            case .replacing:
                return false
            }
        }
    }

    // MARK: - Plugin Ordering

    /// Reorder plugins (for tab bar, settings, etc.)
    func reorderPlugins(_ order: [String]) {
        // Validate all IDs exist
        let validOrder = order.filter { plugins[$0] != nil }
        let missing = Set(pluginOrder).subtracting(Set(validOrder))

        // New order + any missing plugins at the end
        pluginOrder = validOrder + Array(missing)
    }

    /// Move a plugin to a new position
    func movePlugin(_ id: String, to index: Int) {
        guard let currentIndex = pluginOrder.firstIndex(of: id) else { return }
        pluginOrder.remove(at: currentIndex)
        pluginOrder.insert(id, at: min(index, pluginOrder.count))
    }
}

// MARK: - View Helpers

extension PluginManager {
    /// Get the view for a plugin's closed notch content
    @ViewBuilder
    func closedNotchView(for id: String) -> some View {
        if let plugin = plugins[id], plugin.state.isActive {
            plugin.closedNotchContent()
        }
    }

    /// Get the view for a plugin's expanded panel content
    @ViewBuilder
    func expandedPanelView(for id: String) -> some View {
        if let plugin = plugins[id], plugin.state.isActive {
            plugin.expandedPanelContent()
        }
    }

    /// Get the view for a plugin's settings content
    @ViewBuilder
    func settingsView(for id: String) -> some View {
        if let plugin = plugins[id] {
            plugin.settingsContent()
        }
    }
}

// MARK: - Export Support

extension PluginManager {
    /// Get all exportable plugins
    var exportablePlugins: [AnyNotchPlugin] {
        activePlugins.filter { _ in
            // Would check for ExportablePlugin conformance
            // For now, return all active plugins
            true
        }
    }

    /// Export data from a specific plugin
    func exportPluginData(id: String, format: ExportFormat) async throws -> Data {
        guard let plugin = plugins[id] else {
            throw PluginError.notFound(id)
        }

        guard plugin.state.isActive else {
            throw PluginError.invalidState("Plugin not active")
        }

        // Would call plugin.exportData(format:) if it conforms to ExportablePlugin
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
                // Skip plugins that fail to export
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
        // Would use mock services here
        fatalError("Preview not implemented - needs mock services")
    }
}
#endif
