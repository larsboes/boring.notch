//
//  PluginManager+ViewHelpers.swift
//  boringNotch
//
//  Provides SwiftUI Environment integration for PluginManager and related helpers.
//

import SwiftUI

// MARK: - PluginManager Environment Key

private struct PluginManagerKey: EnvironmentKey {
    static let defaultValue: PluginManager? = nil
}

extension EnvironmentValues {
    /// Optional PluginManager for dependency injection into SwiftUI views.
    /// Inject a value with `.environment(\.pluginManager, pluginManager)`.
    /// Defaults to `nil` so previews and isolated views can compile.
    var pluginManager: PluginManager? {
        get { self[PluginManagerKey.self] }
        set { self[PluginManagerKey.self] = newValue }
    }
}
