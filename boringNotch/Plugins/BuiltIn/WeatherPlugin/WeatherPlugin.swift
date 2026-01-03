//
//  WeatherPlugin.swift
//  boringNotch
//
//  Built-in weather plugin.
//  Wraps WeatherService to provide weather updates.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class WeatherPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = "com.boringnotch.weather"
    
    let metadata = PluginMetadata(
        name: "Weather",
        description: "View current weather conditions",
        icon: "cloud.sun.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .utilities
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var weatherService: (any WeatherServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.weatherService = context.services.weather
        self.settings = context.settings
        
        // Start updates if enabled
        if let settings = self.settings, settings.get("showWeather", default: false) {
             self.weatherService?.startUpdatingWeather()
        }
        
        state = .active
    }
    
    func deactivate() async {
        weatherService?.stopUpdatingWeather()
        weatherService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    func closedNotchContent() -> AnyView? {
        return nil
    }
    
    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        return AnyView(WeatherView())
    }
    
    func settingsContent() -> AnyView? {
        AnyView(WeatherSettings())
    }
}
