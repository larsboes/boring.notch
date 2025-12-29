//
//  NotchSettings.swift
//  boringNotch
//
//  Created as part of Phase 1 architectural refactoring.
//  Abstracts settings access for testability.
//

import Foundation
import Defaults

/// Protocol abstracting all notch-related settings.
/// This enables dependency injection and mocking for tests.
protocol NotchSettings {
    // MARK: - HUD Settings
    var showInlineHUD: Bool { get }
    var hudReplacement: Bool { get }
    var showOpenNotchHUD: Bool { get }
    var showOpenNotchHUDPercentage: Bool { get }
    var showClosedNotchHUDPercentage: Bool { get }

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool { get }
    var showBatteryIndicator: Bool { get }
    var showBatteryPercentage: Bool { get }

    // MARK: - Appearance Settings
    var showNotHumanFace: Bool { get }
    var lightingEffect: Bool { get }
    var enableShadow: Bool { get }
    var cornerRadiusScaling: Bool { get }

    // MARK: - Music & Media Settings
    var enableSneakPeek: Bool { get }
    var sneakPeekStyles: SneakPeekStyle { get }
    var sneakPeakDuration: Double { get }
    var coloredSpectrogram: Bool { get }
    var playerColorTinting: Bool { get }
    var sliderColor: SliderColorEnum { get }

    // MARK: - Gesture Settings
    var enableGestures: Bool { get }
    var closeGestureEnabled: Bool { get }
    var gestureSensitivity: CGFloat { get }
    var openNotchOnHover: Bool { get }
    var minimumHoverDuration: TimeInterval { get }

    // MARK: - Shelf Settings
    var boringShelf: Bool { get }
    var openShelfByDefault: Bool { get }
    var shelfTapToOpen: Bool { get }
    var expandedDragDetection: Bool { get }

    // MARK: - Display Settings
    var showOnAllDisplays: Bool { get }
    var automaticallySwitchDisplay: Bool { get }

    // MARK: - Notification Settings
    var showShelfNotifications: Bool { get }
    var showSystemNotifications: Bool { get }
}

// MARK: - Production Implementation

/// Production implementation that wraps Defaults (UserDefaults).
struct DefaultsNotchSettings: NotchSettings {
    // MARK: - HUD Settings
    var showInlineHUD: Bool { Defaults[.inlineHUD] }
    var hudReplacement: Bool { Defaults[.hudReplacement] }
    var showOpenNotchHUD: Bool { Defaults[.showOpenNotchHUD] }
    var showOpenNotchHUDPercentage: Bool { Defaults[.showOpenNotchHUDPercentage] }
    var showClosedNotchHUDPercentage: Bool { Defaults[.showClosedNotchHUDPercentage] }

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool { Defaults[.showPowerStatusNotifications] }
    var showBatteryIndicator: Bool { Defaults[.showBatteryIndicator] }
    var showBatteryPercentage: Bool { Defaults[.showBatteryPercentage] }

    // MARK: - Appearance Settings
    var showNotHumanFace: Bool { Defaults[.showNotHumanFace] }
    var lightingEffect: Bool { Defaults[.lightingEffect] }
    var enableShadow: Bool { Defaults[.enableShadow] }
    var cornerRadiusScaling: Bool { Defaults[.cornerRadiusScaling] }

    // MARK: - Music & Media Settings
    var enableSneakPeek: Bool { Defaults[.enableSneakPeek] }
    var sneakPeekStyles: SneakPeekStyle { Defaults[.sneakPeekStyles] }
    var sneakPeakDuration: Double { Defaults[.sneakPeakDuration] }
    var coloredSpectrogram: Bool { Defaults[.coloredSpectrogram] }
    var playerColorTinting: Bool { Defaults[.playerColorTinting] }
    var sliderColor: SliderColorEnum { Defaults[.sliderColor] }

    // MARK: - Gesture Settings
    var enableGestures: Bool { Defaults[.enableGestures] }
    var closeGestureEnabled: Bool { Defaults[.closeGestureEnabled] }
    var gestureSensitivity: CGFloat { Defaults[.gestureSensitivity] }
    var openNotchOnHover: Bool { Defaults[.openNotchOnHover] }
    var minimumHoverDuration: TimeInterval { Defaults[.minimumHoverDuration] }

    // MARK: - Shelf Settings
    var boringShelf: Bool { Defaults[.boringShelf] }
    var openShelfByDefault: Bool { Defaults[.openShelfByDefault] }
    var shelfTapToOpen: Bool { Defaults[.shelfTapToOpen] }
    var expandedDragDetection: Bool { Defaults[.expandedDragDetection] }

    // MARK: - Display Settings
    var showOnAllDisplays: Bool { Defaults[.showOnAllDisplays] }
    var automaticallySwitchDisplay: Bool { Defaults[.automaticallySwitchDisplay] }

    // MARK: - Notification Settings
    var showShelfNotifications: Bool { Defaults[.showShelfNotifications] }
    var showSystemNotifications: Bool { Defaults[.showSystemNotifications] }
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
    var showClosedNotchHUDPercentage: Bool = false

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool = true
    var showBatteryIndicator: Bool = true
    var showBatteryPercentage: Bool = true

    // MARK: - Appearance Settings
    var showNotHumanFace: Bool = false
    var lightingEffect: Bool = true
    var enableShadow: Bool = true
    var cornerRadiusScaling: Bool = true

    // MARK: - Music & Media Settings
    var enableSneakPeek: Bool = false
    var sneakPeekStyles: SneakPeekStyle = .standard
    var sneakPeakDuration: Double = 1.5
    var coloredSpectrogram: Bool = true
    var playerColorTinting: Bool = true
    var sliderColor: SliderColorEnum = .white

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

    // MARK: - Display Settings
    var showOnAllDisplays: Bool = false
    var automaticallySwitchDisplay: Bool = true

    // MARK: - Notification Settings
    var showShelfNotifications: Bool = true
    var showSystemNotifications: Bool = true
}
