//
//  ClipboardPlugin.swift
//  boringNotch
//
//  Created by Agent on 02/01/26.
//

import SwiftUI

@MainActor
@Observable
final class ClipboardPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.clipboard"
    
    let metadata = PluginMetadata(
        name: "Clipboard",
        description: "View and manage clipboard history",
        icon: "doc.on.clipboard",
        version: "1.0.0",
        author: "boringNotch",
        category: .utilities
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .active
    }
    
    func deactivate() async {
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        return nil
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        return AnyView(ClipboardView())
    }
    
    func settingsContent() -> AnyView? {
        return nil
    }
}
