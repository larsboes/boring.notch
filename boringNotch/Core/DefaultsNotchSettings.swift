//
//  DefaultsNotchSettings.swift
//  boringNotch
//
//  Production implementation of NotchSettings wrapping Defaults (UserDefaults).
//  Uses @Observable to support SwiftUI bindings via @Bindable.
//
//  NOTE: This file exceeds the 300-line limit by design — it is a pure
//  mechanical data-mapping class with no logic, one get/set per Defaults key.
//

import Foundation
import Defaults
import SwiftUI

@MainActor
@Observable
final class DefaultsNotchSettings: NotchSettings {
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

    // MARK: - Appearance Settings
    var alwaysShowTabs: Bool {
        get { Defaults[.alwaysShowTabs] }
        set { Defaults[.alwaysShowTabs] = newValue }
    }
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
    var musicLiveActivityEnabled: Bool {
        get { Defaults[.musicLiveActivityEnabled] }
        set { Defaults[.musicLiveActivityEnabled] = newValue }
    }
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
    var musicControlSlots: [MusicControlButton] {
        get { Defaults[.musicControlSlots] }
        set { Defaults[.musicControlSlots] = newValue }
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
    var shelfHoverDelay: TimeInterval {
        get { Defaults[.shelfHoverDelay] }
        set { Defaults[.shelfHoverDelay] = newValue }
    }

    // MARK: - Display Settings
    var openLastTabByDefault: Bool {
        get { Defaults[.openLastTabByDefault] }
        set { Defaults[.openLastTabByDefault] = newValue }
    }
    var preferredScreenUUID: String? {
        get { Defaults[.preferredScreenUUID] }
        set { Defaults[.preferredScreenUUID] = newValue }
    }
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
