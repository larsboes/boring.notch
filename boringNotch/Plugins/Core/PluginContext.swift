//
//  PluginContext.swift
//  boringNotch
//
//  Dependency injection context provided to plugins during activation.
//  Uses existing types from the codebase - does NOT redefine them.
//

import Foundation
import Combine
import AppKit

// MARK: - Plugin Context

/// Injected into plugins during activation.
/// Provides access to services, settings, and inter-plugin communication.
@MainActor
final class PluginContext {
    /// Plugin-specific settings (namespaced in Defaults)
    let settings: PluginSettings

    /// Access to shared services
    let services: ServiceContainer

    /// For inter-plugin communication
    let eventBus: PluginEventBus

    /// App-wide state
    let appState: AppStateProviding

    init(
        settings: PluginSettings,
        services: ServiceContainer,
        eventBus: PluginEventBus,
        appState: AppStateProviding
    ) {
        self.settings = settings
        self.services = services
        self.eventBus = eventBus
        self.appState = appState
    }
}

// MARK: - App State Protocol

/// Provides access to app-wide state
/// Note: Kept minimal for MVP - expand as features migrate to plugin system
@MainActor
protocol AppStateProviding: AnyObject {
    /// Whether the screen is currently locked
    var isScreenLocked: Bool { get }
}

// MARK: - Service Protocols
// Note: MusicServiceProtocol is defined in Services/MusicServiceProtocol.swift
// Note: Types like PlaybackState, RepeatMode are in models/PlaybackState.swift
// Note: ShelfItem is in components/Shelf/Models/ShelfItem.swift
// Note: WeatherData is in managers/WeatherManager.swift
// Note: BluetoothDevice is in managers/BluetoothManager.swift

/// Calendar service wrapping EventKit
@MainActor
protocol CalendarServiceProtocol: Observable {
    var todayEvents: [CalendarEvent] { get }
    var upcomingEvents: [CalendarEvent] { get }
    var hasAccess: Bool { get }

    func requestAccess() async throws -> Bool
    func refreshEvents() async throws
    func events(for date: Date) async -> [CalendarEvent]
}

struct CalendarEvent: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarColor: String
    let calendarTitle: String

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        calendarColor: String = "#007AFF",
        calendarTitle: String = ""
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.calendarColor = calendarColor
        self.calendarTitle = calendarTitle
    }

    var isMeeting: Bool {
        title.localizedCaseInsensitiveContains("meeting") ||
        title.localizedCaseInsensitiveContains("call") ||
        title.localizedCaseInsensitiveContains("sync")
    }
}

/// Shelf storage service
/// Note: Uses existing ShelfItem from components/Shelf/Models/ShelfItem.swift
@MainActor
protocol ShelfServiceProtocol: Observable {
    var items: [ShelfItem] { get }
    var selectedItemIDs: Set<UUID> { get set }

    func addItem(_ item: ShelfItem) async throws
    func addItems(_ items: [ShelfItem]) async throws
    func removeItem(id: UUID) async throws
    func clearAll() async
}

/// Weather data service
/// Note: Uses existing WeatherData from managers/WeatherManager.swift
@MainActor
protocol WeatherServiceProtocol: Observable {
    var currentWeather: WeatherData? { get }
    var lastUpdated: Date? { get }
    var locationName: String? { get }

    func refresh() async throws
}

/// Volume control service
@MainActor
protocol VolumeServiceProtocol: Observable {
    var volume: Float { get }
    var isMuted: Bool { get }

    func setVolume(_ volume: Float) async
    func toggleMute() async
}

/// Brightness control service
@MainActor
protocol BrightnessServiceProtocol: Observable {
    var brightness: Float { get }

    func setBrightness(_ brightness: Float) async
}

/// Battery status service
@MainActor
protocol BatteryServiceProtocol: Observable {
    var level: Double { get }
    var isCharging: Bool { get }
    var isPluggedIn: Bool { get }
    var timeRemaining: TimeInterval? { get }
}

/// Bluetooth service
/// Note: Uses existing BluetoothDevice from managers/BluetoothManager.swift
@MainActor
protocol BluetoothServiceProtocol: Observable {
    var isEnabled: Bool { get }
    var connectedDevices: [BluetoothDevice] { get }

    func toggleBluetooth() async
}
