import Foundation

/// Container for all services used by plugins.
/// Provides dependency injection for plugin activation.
///
/// Services are optional until their implementations are created during migration.
/// This allows incremental adoption of the plugin architecture.
@MainActor
final class ServiceContainer {
    // MARK: - Core Services

    /// Music playback service (wraps MusicManager)
    let music: any MusicServiceProtocol

    /// Calendar service (wraps CalendarManager) - optional until implemented
    var calendar: (any CalendarServiceProtocol)?

    /// Shelf storage service - optional until implemented
    var shelf: (any ShelfServiceProtocol)?

    /// Weather service (wraps WeatherManager) - optional until implemented
    var weather: (any WeatherServiceProtocol)?

    // MARK: - System Services

    /// Volume control service (wraps VolumeManager) - optional until implemented
    var volume: (any VolumeServiceProtocol)?

    /// Brightness control service (wraps BrightnessManager) - optional until implemented
    var brightness: (any BrightnessServiceProtocol)?

    /// Battery status service (wraps BatteryStatusViewModel) - optional until implemented
    var battery: (any BatteryServiceProtocol)?

    /// Bluetooth service (wraps BluetoothManager) - optional until implemented
    var bluetooth: (any BluetoothServiceProtocol)?

    // MARK: - Initialization

    /// Default initializer - creates services that are ready
    init() {
        self.music = MusicService()
        // Other services will be added as they're migrated
    }

    /// Full initializer for testing or custom configurations
    init(
        music: any MusicServiceProtocol,
        calendar: (any CalendarServiceProtocol)? = nil,
        shelf: (any ShelfServiceProtocol)? = nil,
        weather: (any WeatherServiceProtocol)? = nil,
        volume: (any VolumeServiceProtocol)? = nil,
        brightness: (any BrightnessServiceProtocol)? = nil,
        battery: (any BatteryServiceProtocol)? = nil,
        bluetooth: (any BluetoothServiceProtocol)? = nil
    ) {
        self.music = music
        self.calendar = calendar
        self.shelf = shelf
        self.weather = weather
        self.volume = volume
        self.brightness = brightness
        self.battery = battery
        self.bluetooth = bluetooth
    }
}
