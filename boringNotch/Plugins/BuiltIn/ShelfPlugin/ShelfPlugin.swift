//
//  ShelfPlugin.swift
//  boringNotch
//
//  Built-in shelf plugin.
//  Provides a temporary storage area for files and links.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class ShelfPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.shelf"
    
    let metadata = PluginMetadata(
        name: "Shelf",
        description: "Temporary storage for files and links",
        icon: "tray.full.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var shelfService: (any ShelfServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.shelfService = context.services.shelf
        self.settings = context.settings
        
        state = .active
    }
    
    func deactivate() async {
        shelfService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        return nil
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        // ShelfView uses Environment(\.pluginManager) to access services
        // It also needs BoringViewModel from environment, which NotchHomeView provides
        return AnyView(ShelfView())
    }
    
    func settingsContent() -> AnyView? {
        AnyView(Shelf())
    }
}
