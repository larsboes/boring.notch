//
//  NotchSizeCalculator.swift
//  boringNotch
//
//  Extracted from BoringViewModel - handles notch sizing calculations
//

import SwiftUI

/// Calculator for determining notch sizes based on current state
@MainActor
@Observable class NotchSizeCalculator {
    // MARK: - Dependencies

    /// Settings provider (injected, not direct Defaults access)
    private let settings: NotchViewModelSettings

    /// Display settings for sizing calculations
    private let displaySettings: any DisplaySettings

    /// Music service for checking playback state
    private let musicService: any MusicServiceProtocol

    // MARK: - State

    var notchSize: CGSize = .zero
    var closedNotchSize: CGSize = .zero
    var inactiveNotchSize: CGSize = .zero

    // MARK: - Initialization

    init(
        settings: NotchViewModelSettings,
        displaySettings: any DisplaySettings,
        musicService: any MusicServiceProtocol
    ) {
        self.settings = settings
        self.displaySettings = displaySettings
        self.musicService = musicService
        
        let initialInactive = getInactiveNotchSize(settings: displaySettings)
        self.inactiveNotchSize = initialInactive
        
        // Initial notch size should account for potential live activities at startup
        let hasLiveAtStart = musicService.playbackState.isPlaying || settings.showNotHumanFace
        let initialClosed = getClosedNotchSize(settings: displaySettings, hasLiveActivity: hasLiveAtStart)
        
        self.notchSize = initialClosed
        self.closedNotchSize = initialClosed
    }

    // MARK: - Size Calculation

    /// Updates notch size based on current screen and state
    func updateNotchSize(
        screenUUID: String?,
        currentState: NotchState
    ) -> (closedSize: CGSize, inactiveSize: CGSize, shouldUpdateNotchSize: Bool) {
        let newClosedSize = getClosedNotchSize(settings: displaySettings, screenUUID: screenUUID)
        let newInactiveSize = getInactiveNotchSize(settings: displaySettings, screenUUID: screenUUID)

        self.closedNotchSize = newClosedSize
        self.inactiveNotchSize = newInactiveSize

        let shouldUpdateNotchSize = currentState == .closed

        return (newClosedSize, newInactiveSize, shouldUpdateNotchSize)
    }

    /// Calculate effective closed notch height based on current state
    func effectiveClosedNotchHeight(
        screenUUID: String?,
        hideOnClosed: Bool,
        sneakPeekActive: Bool,
        expandingViewActive: Bool,
        expandingViewType: SneakContentType?,
        pluginPreferredHeight: CGFloat? = nil
    ) -> CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)

        if noNotchAndFullscreen {
            return 0
        }

        // Plugin with explicit height preference takes priority (e.g. teleprompter needs double height)
        if let preferred = pluginPreferredHeight {
            return preferred
        }

        // Check if any live activity is active
        let isFaceActive = !musicService.playbackState.isPlaying &&
                           musicService.isPlayerIdle &&
                           settings.showNotHumanFace

        let hasActiveLiveActivity = musicService.playbackState.isPlaying ||
                                    sneakPeekActive ||
                                    (expandingViewActive && expandingViewType == .battery) ||
                                    isFaceActive

        // Use inactive height when there's no live activity
        if hasActiveLiveActivity {
            return getClosedNotchSize(settings: displaySettings, screenUUID: screenUUID, hasLiveActivity: true).height
        } else {
            return inactiveNotchSize.height
        }
    }

    /// Calculate chin height (menu bar offset compensation)
    func chinHeight(
        screenUUID: String?,
        notchState: NotchState,
        effectiveClosedHeight: CGFloat
    ) -> CGFloat {
        if !settings.hideTitleBar {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }
}
