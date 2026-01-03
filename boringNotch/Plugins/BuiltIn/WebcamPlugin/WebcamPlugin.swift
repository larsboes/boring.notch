//
//  WebcamPlugin.swift
//  boringNotch
//
//  Built-in webcam plugin.
//  Wraps WebcamManager to provide camera mirror.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class WebcamPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.webcam"
    
    let metadata = PluginMetadata(
        name: "Webcam Mirror",
        description: "Mirror your camera in the notch",
        icon: "camera.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .utilities
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var webcamService: (any WebcamServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.webcamService = context.services.webcam
        self.settings = context.settings
        
        // Check for camera availability
        self.webcamService?.checkAndRequestVideoAuthorization()
        
        state = .active
    }
    
    func deactivate() async {
        webcamService?.stopSession()
        webcamService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        return nil
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive, let service = webcamService else { return nil }
        return AnyView(CameraPreviewView(webcamManager: service))
    }
    
    func settingsContent() -> AnyView? {
        // No dedicated settings view yet, relies on General settings (showMirror)
        // Could return a view that toggles "showMirror" via plugin settings
        return nil
    }
}
