//
//  NotchPlugin.swift
//  boringNotch
//
//  Core plugin protocol that every plugin must implement.
//

import SwiftUI
import Combine

// MARK: - Core Plugin Protocol

/// The fundamental protocol every plugin must implement.
/// Defines identity, lifecycle, and UI slots.
@MainActor
protocol NotchPlugin: Identifiable, Observable, AnyObject {
    /// Unique reverse-DNS identifier (e.g., "com.boringnotch.music")
    var id: String { get }

    /// Display metadata for settings UI
    var metadata: PluginMetadata { get }

    /// Whether user has enabled this plugin
    var isEnabled: Bool { get set }

    /// Current loading/error state
    var state: PluginState { get }

    // MARK: - Lifecycle

    /// Called when plugin is enabled. Set up observers, load data.
    /// - Parameter context: Provides access to services, settings, and event bus
    func activate(context: PluginContext) async throws

    /// Called when plugin is disabled. Clean up resources.
    func deactivate() async

    // MARK: - UI Slots

    /// Content shown in the closed notch (compact view)
    /// Return nil if this plugin doesn't show in closed state
    @ViewBuilder
    func closedNotchContent() -> AnyView?

    /// Content shown when notch is expanded (full panel)
    /// Return nil if this plugin doesn't have an expanded view
    @ViewBuilder
    func expandedPanelContent() -> AnyView?

    /// Settings UI for this plugin
    @ViewBuilder
    func settingsContent() -> AnyView?
}

// MARK: - Default Implementations

extension NotchPlugin {
    /// Default: no closed notch content
    func closedNotchContent() -> AnyView? { nil }

    /// Default: no expanded panel content
    func expandedPanelContent() -> AnyView? { nil }

    /// Default: no custom settings (uses auto-generated toggle)
    func settingsContent() -> AnyView? { nil }
}

// MARK: - Plugin Metadata

struct PluginMetadata: Sendable, Hashable {
    let name: String
    let description: String
    let icon: String  // SF Symbol name
    let version: String
    let author: String
    let category: PluginCategory

    init(
        name: String,
        description: String,
        icon: String,
        version: String = "1.0.0",
        author: String = "boringNotch",
        category: PluginCategory = .utilities
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self.version = version
        self.author = author
        self.category = category
    }
}

enum PluginCategory: String, CaseIterable, Sendable {
    case media
    case productivity
    case utilities
    case system
    case social

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .media: return "play.circle"
        case .productivity: return "checkmark.circle"
        case .utilities: return "wrench.and.screwdriver"
        case .system: return "gearshape"
        case .social: return "person.2"
        }
    }
}

// MARK: - Plugin State

enum PluginState: Sendable, Equatable {
    case inactive
    case activating
    case active
    case error(PluginError)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Plugin Error

enum PluginError: Error, LocalizedError, Sendable, Equatable {
    case notFound(String)
    case activationFailed(String)
    case permissionDenied(String)
    case invalidState(String)
    case exportFailed(String)
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Plugin not found: \(id)"
        case .activationFailed(let reason):
            return "Activation failed: \(reason)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .invalidState(let state):
            return "Invalid state: \(state)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service)"
        }
    }
}

// MARK: - Type Erasure Helper

/// Type-erased wrapper for any NotchPlugin
@MainActor
struct AnyNotchPlugin: Identifiable {
    let id: String
    private let _metadata: () -> PluginMetadata
    private let _isEnabled: () -> Bool
    private let _setEnabled: (Bool) -> Void
    private let _state: () -> PluginState
    private let _activate: (PluginContext) async throws -> Void
    private let _deactivate: () async -> Void
    private let _closedNotchContent: () -> AnyView?
    private let _expandedPanelContent: () -> AnyView?
    private let _settingsContent: () -> AnyView?

    init<P: NotchPlugin>(_ plugin: P) {
        self.id = plugin.id
        self._metadata = { plugin.metadata }
        self._isEnabled = { plugin.isEnabled }
        self._setEnabled = { plugin.isEnabled = $0 }
        self._state = { plugin.state }
        self._activate = { try await plugin.activate(context: $0) }
        self._deactivate = { await plugin.deactivate() }
        self._closedNotchContent = { plugin.closedNotchContent() }
        self._expandedPanelContent = { plugin.expandedPanelContent() }
        self._settingsContent = { plugin.settingsContent() }
    }

    var metadata: PluginMetadata { _metadata() }
    var isEnabled: Bool {
        get { _isEnabled() }
        nonmutating set { _setEnabled(newValue) }
    }
    var state: PluginState { _state() }

    func activate(context: PluginContext) async throws {
        try await _activate(context)
    }

    func deactivate() async {
        await _deactivate()
    }

    func closedNotchContent() -> AnyView? { _closedNotchContent() }
    func expandedPanelContent() -> AnyView? { _expandedPanelContent() }
    func settingsContent() -> AnyView? { _settingsContent() }
}
