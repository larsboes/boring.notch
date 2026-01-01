//
//  NotchSettings.swift
//  boringNotch
//
//  Created as part of Phase 1 architectural refactoring.
//  Abstracts settings access for testability.
//

import Foundation
import Defaults
import SwiftUI

/// Protocol abstracting all notch-related settings.
/// This enables dependency injection and mocking for tests.
protocol NotchSettings {
    // MARK: - HUD Settings
    var showInlineHUD: Bool { get }
    var hudReplacement: Bool { get set }
    var showOpenNotchHUD: Bool { get set }
    var showOpenNotchHUDPercentage: Bool { get set }
    var showClosedNotchHUDPercentage: Bool { get set }
    var showBatteryPercentage: Bool { get set }
    var inlineHUD: Bool { get set }
    var optionKeyAction: OptionKeyAction { get set }
    var enableGradient: Bool { get set }
    var systemEventIndicatorUseAccent: Bool { get set }
    var systemEventIndicatorShadow: Bool { get set }

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool { get set }
    var showBatteryIndicator: Bool { get set }
    var showPowerStatusIcons: Bool { get set }
    var powerStatusNotificationSound: String { get set }
    var lowBatteryNotificationLevel: Int { get set }
    var lowBatteryNotificationSound: String { get set }
    var highBatteryNotificationLevel: Int { get set }
    var highBatteryNotificationSound: String { get set }
    // var showBatteryPercentage: Bool { get } // This property is moved to HUD settings and made settable

    // MARK: - Appearance Settings
    var showNotHumanFace: Bool { get set }
    var lightingEffect: Bool { get set }
    var liquidGlassEffect: Bool { get set }
    var liquidGlassStyle: LiquidGlassStyle { get set }
    var liquidGlassBlurRadius: Double { get set }
    var backgroundImageURL: URL? { get set }
    var enableShadow: Bool { get set }
    var cornerRadiusScaling: Bool { get set }
    var settingsIconInNotch: Bool { get set }
    var menubarIcon: Bool { get set }

    // MARK: - Music & Media Settings
    var enableSneakPeek: Bool { get set }
    var sneakPeekStyles: SneakPeekStyle { get set }
    var sneakPeakDuration: Double { get set }
    var coloredSpectrogram: Bool { get set }
    var playerColorTinting: Bool { get set }
    var sliderColor: SliderColorEnum { get set }
    var enableLyrics: Bool { get set }
    var selectedMood: Mood { get set }
    var waitInterval: Double { get set }
    var hideNotchOption: HideNotchOption { get set }
    var mediaController: MediaControllerType { get set }
    var mirrorShape: MirrorShapeEnum { get set }

    // MARK: - Gesture Settings
    var enableGestures: Bool { get set }
    var closeGestureEnabled: Bool { get set }
    var gestureSensitivity: CGFloat { get set }
    var openNotchOnHover: Bool { get set }
    var minimumHoverDuration: TimeInterval { get set }

    // MARK: - Shelf Settings
    var boringShelf: Bool { get set }
    var openShelfByDefault: Bool { get set }
    var shelfTapToOpen: Bool { get set }
    var expandedDragDetection: Bool { get set }
    var copyOnDrag: Bool { get set }
    var autoRemoveShelfItems: Bool { get set }
    var quickShareProvider: String { get set }

    // MARK: - Display Settings
    var showOnAllDisplays: Bool { get set }
    var automaticallySwitchDisplay: Bool { get set }
    var hideTitleBar: Bool { get set }
    var extendHoverArea: Bool { get set }
    var showOnLockScreen: Bool { get set }
    var hideFromScreenRecording: Bool { get set }
    var hideNonNotchedFromMissionControl: Bool { get set }
    var useCustomAccentColor: Bool { get set }
    var customAccentColorData: Data? { get set }
    var releaseName: String { get }
    var nonNotchHeight: Double { get set }
    var nonNotchHeightMode: WindowHeightMode { get set }
    var notchHeight: Double { get set }
    var notchHeightMode: WindowHeightMode { get set }
    var inactiveNotchHeight: Double { get set }
    var useInactiveNotchHeight: Bool { get set }

    // MARK: - Widget Settings
    var showMirror: Bool { get set }
    var showCalendar: Bool { get set }
    var showWeather: Bool { get set }
    var openWeatherMapApiKey: String { get set }
    
    // MARK: - Calendar Settings
    var enableHaptics: Bool { get set }
    var hideCompletedReminders: Bool { get set }
    var hideAllDayEvents: Bool { get set }
    var autoScrollToNextEvent: Bool { get set }
    var showFullEventTitles: Bool { get set }

    // MARK: - Notification Settings
    var showShelfNotifications: Bool { get set }
    var showSystemNotifications: Bool { get set }
    var showInfoNotifications: Bool { get set }
    var notificationDeliveryStyle: NotificationDeliveryStyle { get set }
    var notificationSoundEnabled: Bool { get set }
    var respectDoNotDisturb: Bool { get set }
    var notificationRetentionDays: Int { get set }
    
    // MARK: - Bluetooth Settings
    var enableBluetoothSneakPeek: Bool { get set }
    var bluetoothSneakPeekStyle: SneakPeekStyle { get set }
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] { get set }
}

// MARK: - Production Implementation

/// Production implementation that wraps Defaults (UserDefaults).
/// Uses @Observable to support SwiftUI bindings via @Bindable.
@MainActor
@Observable
final class DefaultsNotchSettings: NotchSettings {
    /// Shared singleton instance for use with @Bindable in views
    static let shared = DefaultsNotchSettings()
    // MARK: - HUD Settings
    var showInlineHUD: Bool { Defaults[.inlineHUD] }
    var hudReplacement: Bool {
        get { Defaults[.hudReplacement] }
        set { Defaults[.hudReplacement] = newValue }
    }
    var showOpenNotchHUD: Bool {
        get { Defaults[.showOpenNotchHUD] }
        set { Defaults[.showOpenNotchHUD] = newValue }
    }
    var showOpenNotchHUDPercentage: Bool {
        get { Defaults[.showOpenNotchHUDPercentage] }
        set { Defaults[.showOpenNotchHUDPercentage] = newValue }
    }
    var showClosedNotchHUDPercentage: Bool {
        get { Defaults[.showClosedNotchHUDPercentage] }
        set { Defaults[.showClosedNotchHUDPercentage] = newValue }
    }
    var showBatteryPercentage: Bool {
        get { Defaults[.showBatteryPercentage] }
        set { Defaults[.showBatteryPercentage] = newValue }
    }
    var inlineHUD: Bool {
        get { Defaults[.inlineHUD] }
        set { Defaults[.inlineHUD] = newValue }
    }
    var optionKeyAction: OptionKeyAction {
        get { Defaults[.optionKeyAction] }
        set { Defaults[.optionKeyAction] = newValue }
    }
    var enableGradient: Bool {
        get { Defaults[.enableGradient] }
        set { Defaults[.enableGradient] = newValue }
    }
    var systemEventIndicatorUseAccent: Bool {
        get { Defaults[.systemEventIndicatorUseAccent] }
        set { Defaults[.systemEventIndicatorUseAccent] = newValue }
    }
    var systemEventIndicatorShadow: Bool {
        get { Defaults[.systemEventIndicatorShadow] }
        set { Defaults[.systemEventIndicatorShadow] = newValue }
    }

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool {
        get { Defaults[.showPowerStatusNotifications] }
        set { Defaults[.showPowerStatusNotifications] = newValue }
    }
    var showBatteryIndicator: Bool {
        get { Defaults[.showBatteryIndicator] }
        set { Defaults[.showBatteryIndicator] = newValue }
    }
    var showPowerStatusIcons: Bool {
        get { Defaults[.showPowerStatusIcons] }
        set { Defaults[.showPowerStatusIcons] = newValue }
    }
    var powerStatusNotificationSound: String {
        get { Defaults[.powerStatusNotificationSound] }
        set { Defaults[.powerStatusNotificationSound] = newValue }
    }
    var lowBatteryNotificationLevel: Int {
        get { Defaults[.lowBatteryNotificationLevel] }
        set { Defaults[.lowBatteryNotificationLevel] = newValue }
    }
    var lowBatteryNotificationSound: String {
        get { Defaults[.lowBatteryNotificationSound] }
        set { Defaults[.lowBatteryNotificationSound] = newValue }
    }
    var highBatteryNotificationLevel: Int {
        get { Defaults[.highBatteryNotificationLevel] }
        set { Defaults[.highBatteryNotificationLevel] = newValue }
    }
    var highBatteryNotificationSound: String {
        get { Defaults[.highBatteryNotificationSound] }
        set { Defaults[.highBatteryNotificationSound] = newValue }
    }
    // var showBatteryPercentage: Bool { Defaults[.showBatteryPercentage] } // This property is moved to HUD settings and made settable

    // MARK: - Appearance Settings
    var showNotHumanFace: Bool {
        get { Defaults[.showNotHumanFace] }
        set { Defaults[.showNotHumanFace] = newValue }
    }
    var lightingEffect: Bool {
        get { Defaults[.lightingEffect] }
        set { Defaults[.lightingEffect] = newValue }
    }
    var liquidGlassEffect: Bool {
        get { Defaults[.liquidGlassEffect] }
        set { Defaults[.liquidGlassEffect] = newValue }
    }
    var liquidGlassStyle: LiquidGlassStyle {
        get { Defaults[.liquidGlassStyle] }
        set { Defaults[.liquidGlassStyle] = newValue }
    }
    var liquidGlassBlurRadius: Double {
        get { Defaults[.liquidGlassBlurRadius] }
        set { Defaults[.liquidGlassBlurRadius] = newValue }
    }
    var backgroundImageURL: URL? {
        get { Defaults[.backgroundImageURL] }
        set { Defaults[.backgroundImageURL] = newValue }
    }
    var enableShadow: Bool {
        get { Defaults[.enableShadow] }
        set { Defaults[.enableShadow] = newValue }
    }
    var cornerRadiusScaling: Bool {
        get { Defaults[.cornerRadiusScaling] }
        set { Defaults[.cornerRadiusScaling] = newValue }
    }
    var settingsIconInNotch: Bool {
        get { Defaults[.settingsIconInNotch] }
        set { Defaults[.settingsIconInNotch] = newValue }
    }
    var menubarIcon: Bool {
        get { Defaults[.menubarIcon] }
        set { Defaults[.menubarIcon] = newValue }
    }

    // MARK: - Music & Media Settings
    var enableSneakPeek: Bool {
        get { Defaults[.enableSneakPeek] }
        set { Defaults[.enableSneakPeek] = newValue }
    }
    var sneakPeekStyles: SneakPeekStyle {
        get { Defaults[.sneakPeekStyles] }
        set { Defaults[.sneakPeekStyles] = newValue }
    }
    var sneakPeakDuration: Double {
        get { Defaults[.sneakPeakDuration] }
        set { Defaults[.sneakPeakDuration] = newValue }
    }
    var coloredSpectrogram: Bool {
        get { Defaults[.coloredSpectrogram] }
        set { Defaults[.coloredSpectrogram] = newValue }
    }
    var playerColorTinting: Bool {
        get { Defaults[.playerColorTinting] }
        set { Defaults[.playerColorTinting] = newValue }
    }
    var sliderColor: SliderColorEnum {
        get { Defaults[.sliderColor] }
        set { Defaults[.sliderColor] = newValue }
    }
    var enableLyrics: Bool {
        get { Defaults[.enableLyrics] }
        set { Defaults[.enableLyrics] = newValue }
    }
    var selectedMood: Mood {
        get { Defaults[.selectedMood] }
        set { Defaults[.selectedMood] = newValue }
    }
    var waitInterval: Double {
        get { Defaults[.waitInterval] }
        set { Defaults[.waitInterval] = newValue }
    }
    var hideNotchOption: HideNotchOption {
        get { Defaults[.hideNotchOption] }
        set { Defaults[.hideNotchOption] = newValue }
    }
    var mediaController: MediaControllerType {
        get { Defaults[.mediaController] }
        set { Defaults[.mediaController] = newValue }
    }
    var mirrorShape: MirrorShapeEnum {
        get { Defaults[.mirrorShape] }
        set { Defaults[.mirrorShape] = newValue }
    }

    // MARK: - Gesture Settings
    var enableGestures: Bool {
        get { Defaults[.enableGestures] }
        set { Defaults[.enableGestures] = newValue }
    }
    var closeGestureEnabled: Bool {
        get { Defaults[.closeGestureEnabled] }
        set { Defaults[.closeGestureEnabled] = newValue }
    }
    var gestureSensitivity: CGFloat {
        get { Defaults[.gestureSensitivity] }
        set { Defaults[.gestureSensitivity] = newValue }
    }
    var openNotchOnHover: Bool {
        get { Defaults[.openNotchOnHover] }
        set { Defaults[.openNotchOnHover] = newValue }
    }
    var minimumHoverDuration: TimeInterval {
        get { Defaults[.minimumHoverDuration] }
        set { Defaults[.minimumHoverDuration] = newValue }
    }

    // MARK: - Shelf Settings
    var boringShelf: Bool {
        get { Defaults[.boringShelf] }
        set { Defaults[.boringShelf] = newValue }
    }
    var openShelfByDefault: Bool {
        get { Defaults[.openShelfByDefault] }
        set { Defaults[.openShelfByDefault] = newValue }
    }
    var shelfTapToOpen: Bool {
        get { Defaults[.shelfTapToOpen] }
        set { Defaults[.shelfTapToOpen] = newValue }
    }
    var expandedDragDetection: Bool {
        get { Defaults[.expandedDragDetection] }
        set { Defaults[.expandedDragDetection] = newValue }
    }
    var copyOnDrag: Bool {
        get { Defaults[.copyOnDrag] }
        set { Defaults[.copyOnDrag] = newValue }
    }
    var autoRemoveShelfItems: Bool {
        get { Defaults[.autoRemoveShelfItems] }
        set { Defaults[.autoRemoveShelfItems] = newValue }
    }
    var quickShareProvider: String {
        get { Defaults[.quickShareProvider] }
        set { Defaults[.quickShareProvider] = newValue }
    }

    // MARK: - Display Settings
    var showOnAllDisplays: Bool {
        get { Defaults[.showOnAllDisplays] }
        set { Defaults[.showOnAllDisplays] = newValue }
    }
    var automaticallySwitchDisplay: Bool {
        get { Defaults[.automaticallySwitchDisplay] }
        set { Defaults[.automaticallySwitchDisplay] = newValue }
    }
    var hideTitleBar: Bool {
        get { Defaults[.hideTitleBar] }
        set { Defaults[.hideTitleBar] = newValue }
    }
    var extendHoverArea: Bool {
        get { Defaults[.extendHoverArea] }
        set { Defaults[.extendHoverArea] = newValue }
    }
    var showOnLockScreen: Bool {
        get { Defaults[.showOnLockScreen] }
        set { Defaults[.showOnLockScreen] = newValue }
    }
    var hideFromScreenRecording: Bool {
        get { Defaults[.hideFromScreenRecording] }
        set { Defaults[.hideFromScreenRecording] = newValue }
    }
    var hideNonNotchedFromMissionControl: Bool {
        get { Defaults[.hideNonNotchedFromMissionControl] }
        set { Defaults[.hideNonNotchedFromMissionControl] = newValue }
    }
    var useCustomAccentColor: Bool {
        get { Defaults[.useCustomAccentColor] }
        set { Defaults[.useCustomAccentColor] = newValue }
    }
    var customAccentColorData: Data? {
        get { Defaults[.customAccentColorData] }
        set { Defaults[.customAccentColorData] = newValue }
    }
    var releaseName: String { Defaults[.releaseName] }
    var nonNotchHeight: Double {
        get { Defaults[.nonNotchHeight] }
        set { Defaults[.nonNotchHeight] = newValue }
    }
    var nonNotchHeightMode: WindowHeightMode {
        get { Defaults[.nonNotchHeightMode] }
        set { Defaults[.nonNotchHeightMode] = newValue }
    }
    var notchHeight: Double {
        get { Defaults[.notchHeight] }
        set { Defaults[.notchHeight] = newValue }
    }
    var notchHeightMode: WindowHeightMode {
        get { Defaults[.notchHeightMode] }
        set { Defaults[.notchHeightMode] = newValue }
    }
    var inactiveNotchHeight: Double {
        get { Defaults[.inactiveNotchHeight] }
        set { Defaults[.inactiveNotchHeight] = newValue }
    }
    var useInactiveNotchHeight: Bool {
        get { Defaults[.useInactiveNotchHeight] }
        set { Defaults[.useInactiveNotchHeight] = newValue }
    }
    
    // MARK: - Widget Settings
    var showMirror: Bool {
        get { Defaults[.showMirror] }
        set { Defaults[.showMirror] = newValue }
    }
    var showCalendar: Bool {
        get { Defaults[.showCalendar] }
        set { Defaults[.showCalendar] = newValue }
    }
    var showWeather: Bool {
        get { Defaults[.showWeather] }
        set { Defaults[.showWeather] = newValue }
    }
    var openWeatherMapApiKey: String {
        get { Defaults[.openWeatherMapApiKey] }
        set { Defaults[.openWeatherMapApiKey] = newValue }
    }
    
    // MARK: - Calendar Settings
    var enableHaptics: Bool {
        get { Defaults[.enableHaptics] }
        set { Defaults[.enableHaptics] = newValue }
    }
    var hideCompletedReminders: Bool {
        get { Defaults[.hideCompletedReminders] }
        set { Defaults[.hideCompletedReminders] = newValue }
    }
    var hideAllDayEvents: Bool {
        get { Defaults[.hideAllDayEvents] }
        set { Defaults[.hideAllDayEvents] = newValue }
    }
    var autoScrollToNextEvent: Bool {
        get { Defaults[.autoScrollToNextEvent] }
        set { Defaults[.autoScrollToNextEvent] = newValue }
    }
    var showFullEventTitles: Bool {
        get { Defaults[.showFullEventTitles] }
        set { Defaults[.showFullEventTitles] = newValue }
    }

    // MARK: - Notification Settings
    var showShelfNotifications: Bool {
        get { Defaults[.showShelfNotifications] }
        set { Defaults[.showShelfNotifications] = newValue }
    }
    var showSystemNotifications: Bool {
        get { Defaults[.showSystemNotifications] }
        set { Defaults[.showSystemNotifications] = newValue }
    }
    var showInfoNotifications: Bool {
        get { Defaults[.showInfoNotifications] }
        set { Defaults[.showInfoNotifications] = newValue }
    }
    var notificationDeliveryStyle: NotificationDeliveryStyle {
        get { Defaults[.notificationDeliveryStyle] }
        set { Defaults[.notificationDeliveryStyle] = newValue }
    }
    var notificationSoundEnabled: Bool {
        get { Defaults[.notificationSoundEnabled] }
        set { Defaults[.notificationSoundEnabled] = newValue }
    }
    var respectDoNotDisturb: Bool {
        get { Defaults[.respectDoNotDisturb] }
        set { Defaults[.respectDoNotDisturb] = newValue }
    }
    var notificationRetentionDays: Int {
        get { Defaults[.notificationRetentionDays] }
        set { Defaults[.notificationRetentionDays] = newValue }
    }
    
    // MARK: - Bluetooth Settings
    var enableBluetoothSneakPeek: Bool {
        get { Defaults[.enableBluetoothSneakPeek] }
        set { Defaults[.enableBluetoothSneakPeek] = newValue }
    }
    var bluetoothSneakPeekStyle: SneakPeekStyle {
        get { Defaults[.bluetoothSneakPeekStyle] }
        set { Defaults[.bluetoothSneakPeekStyle] = newValue }
    }
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] {
        get { Defaults[.bluetoothDeviceIconMappings] }
        set { Defaults[.bluetoothDeviceIconMappings] = newValue }
    }
}

// MARK: - Mock Implementation for Testing

/// Mock implementation for unit testing.
/// All properties are mutable with sensible defaults.
struct MockNotchSettings: NotchSettings {
    // MARK: - HUD Settings
    var showInlineHUD: Bool = false
    var hudReplacement: Bool = false
    var showOpenNotchHUD: Bool = true
    var showOpenNotchHUDPercentage: Bool = true
    var showClosedNotchHUDPercentage: Bool = true
    var showBatteryPercentage: Bool = true
    var inlineHUD: Bool = false
    var optionKeyAction: OptionKeyAction = .none
    var enableGradient: Bool = true
    var systemEventIndicatorUseAccent: Bool = true
    var systemEventIndicatorShadow: Bool = true

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool = true
    var showBatteryIndicator: Bool = true
    var showPowerStatusIcons: Bool = true
    var powerStatusNotificationSound: String = "Disabled"
    var lowBatteryNotificationLevel: Int = 0
    var lowBatteryNotificationSound: String = "Disabled"
    var highBatteryNotificationLevel: Int = 0
    var highBatteryNotificationSound: String = "Disabled"

    // MARK: - Appearance Settings
    var showNotHumanFace: Bool = false
    var lightingEffect: Bool = true
    var liquidGlassEffect: Bool = false
    var liquidGlassStyle: LiquidGlassStyle = .default
    var liquidGlassBlurRadius: Double = 10.0
    var backgroundImageURL: URL? = nil
    var enableShadow: Bool = true
    var cornerRadiusScaling: Bool = true
    var settingsIconInNotch: Bool = true
    var menubarIcon: Bool = true

    // MARK: - Music & Media Settings
    var enableSneakPeek: Bool = false
    var sneakPeekStyles: SneakPeekStyle = .standard
    var sneakPeakDuration: Double = 1.5
    var coloredSpectrogram: Bool = true
    var playerColorTinting: Bool = true
    var sliderColor: SliderColorEnum = .white
    var enableLyrics: Bool = true
    var selectedMood: Mood = .neutral
    var waitInterval: Double = 5.0
    var hideNotchOption: HideNotchOption = .never
    var mediaController: MediaControllerType = .nowPlaying
    var mirrorShape: MirrorShapeEnum = .circle

    // MARK: - Gesture Settings
    var enableGestures: Bool = true
    var closeGestureEnabled: Bool = true
    var gestureSensitivity: CGFloat = 200.0
    var openNotchOnHover: Bool = true
    var minimumHoverDuration: TimeInterval = 0.3

    // MARK: - Shelf Settings
    var boringShelf: Bool = true
    var openShelfByDefault: Bool = true
    var shelfTapToOpen: Bool = true
    var expandedDragDetection: Bool = true
    var copyOnDrag: Bool = false
    var autoRemoveShelfItems: Bool = false
    var quickShareProvider: String = "com.apple.share.AirDrop"

    // MARK: - Display Settings
    var showOnAllDisplays: Bool = false
    var automaticallySwitchDisplay: Bool = true
    var hideTitleBar: Bool = false
    var extendHoverArea: Bool = false
    var showOnLockScreen: Bool = false
    var hideFromScreenRecording: Bool = false
    var hideNonNotchedFromMissionControl: Bool = true
    var useCustomAccentColor: Bool = false
    var customAccentColorData: Data? = nil
    var releaseName: String = "Boring Notch"
    var nonNotchHeight: Double = 23.0
    var nonNotchHeightMode: WindowHeightMode = .matchMenuBar
    var notchHeight: Double = 38.0
    var notchHeightMode: WindowHeightMode = .matchRealNotchSize
    var inactiveNotchHeight: Double = 23.0
    var useInactiveNotchHeight: Bool = false
    
    // MARK: - Widget Settings
    var showMirror: Bool = false
    var showCalendar: Bool = true
    var showWeather: Bool = true
    var openWeatherMapApiKey: String = ""
    
    // MARK: - Calendar Settings
    var enableHaptics: Bool = true
    var hideCompletedReminders: Bool = false
    var hideAllDayEvents: Bool = false
    var autoScrollToNextEvent: Bool = true
    var showFullEventTitles: Bool = false

    // MARK: - Notification Settings
    var showShelfNotifications: Bool = true
    var showSystemNotifications: Bool = true
    var showInfoNotifications: Bool = true
    var notificationDeliveryStyle: NotificationDeliveryStyle = .banner
    var notificationSoundEnabled: Bool = true
    var respectDoNotDisturb: Bool = true
    var notificationRetentionDays: Int = 7
    
    // MARK: - Bluetooth Settings
    var enableBluetoothSneakPeek: Bool = true
    var bluetoothSneakPeekStyle: SneakPeekStyle = .standard
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] = []
}

// MARK: - Environment Keys

/// Read-only environment key for protocol-based DI (testable with MockNotchSettings)
private struct NotchSettingsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: any NotchSettings = DefaultsNotchSettings.shared
}

extension EnvironmentValues {
    /// Read-only settings access for views that don't need binding.
    /// Use `MockNotchSettings()` for testing.
    var settings: any NotchSettings {
        get { self[NotchSettingsKey.self] }
        set { self[NotchSettingsKey.self] = newValue }
    }
}

/// Bindable environment key for settings views that need two-way binding
private struct BindableNotchSettingsKey: EnvironmentKey {
    @MainActor static var defaultValue: DefaultsNotchSettings {
        DefaultsNotchSettings.shared
    }
}

extension EnvironmentValues {
    /// Bindable settings access for views that need two-way binding.
    /// Use with `@Environment(\.bindableSettings) @Bindable var settings`
    var bindableSettings: DefaultsNotchSettings {
        get { self[BindableNotchSettingsKey.self] }
        set { self[BindableNotchSettingsKey.self] = newValue }
    }
}
