//
//  NotchStateMachine.swift
//  boringNotch
//
//  Created as part of Phase 1 architectural refactoring.
//  Centralizes state determination logic from ContentView.
//

import Foundation
import SwiftUI
import Defaults

// MARK: - Display State Types

/// Represents what the notch should display at any given moment.
/// This enum centralizes the branching logic currently scattered in ContentView.
enum NotchDisplayState: Equatable {
    case closed(content: ClosedContent)
    case open(view: NotchViews)
    case helloAnimation
    case sneakPeek(type: SneakContentType, value: CGFloat, icon: String)
    case expanding(type: SneakContentType)

    /// Content displayed when the notch is closed
    enum ClosedContent: Equatable {
        case idle
        case musicLiveActivity
        case batteryNotification
        case face
        case inlineHUD(type: SneakContentType, value: CGFloat, icon: String)
        case sneakPeek(type: SneakContentType, value: CGFloat, icon: String)
    }
}

// MARK: - State Machine Input

/// All inputs needed to determine the current display state.
/// Extracted from various sources (coordinator, music manager, settings, etc.)
struct NotchStateInput: Equatable {
    // Core state
    var notchState: NotchState
    var currentView: NotchViews

    // Coordinator state
    var helloAnimationRunning: Bool
    var sneakPeek: sneakPeek
    var expandingView: ExpandedItem
    var musicLiveActivityEnabled: Bool

    // Music state
    var isPlaying: Bool
    var isPlayerIdle: Bool

    // View model state
    var hideOnClosed: Bool

    // Settings (can be injected for testing)
    var showPowerStatusNotifications: Bool
    var showInlineHUD: Bool
    var showNotHumanFace: Bool
    var sneakPeekStyle: SneakPeekStyle

    static func == (lhs: NotchStateInput, rhs: NotchStateInput) -> Bool {
        lhs.notchState == rhs.notchState &&
        lhs.currentView == rhs.currentView &&
        lhs.helloAnimationRunning == rhs.helloAnimationRunning &&
        lhs.sneakPeek.show == rhs.sneakPeek.show &&
        lhs.sneakPeek.type == rhs.sneakPeek.type &&
        lhs.expandingView.show == rhs.expandingView.show &&
        lhs.expandingView.type == rhs.expandingView.type &&
        lhs.musicLiveActivityEnabled == rhs.musicLiveActivityEnabled &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.isPlayerIdle == rhs.isPlayerIdle &&
        lhs.hideOnClosed == rhs.hideOnClosed &&
        lhs.showPowerStatusNotifications == rhs.showPowerStatusNotifications &&
        lhs.showInlineHUD == rhs.showInlineHUD &&
        lhs.showNotHumanFace == rhs.showNotHumanFace &&
        lhs.sneakPeekStyle == rhs.sneakPeekStyle
    }
}

// MARK: - State Machine

/// Centralizes state determination logic.
/// This class extracts the complex if-else chains from ContentView into a testable component.
@MainActor
class NotchStateMachine: ObservableObject {
    static let shared = NotchStateMachine()

    @Published private(set) var displayState: NotchDisplayState = .closed(content: .idle)
    @Published private(set) var lastInput: NotchStateInput?

    private init() {}

    /// Compute the display state based on current inputs.
    /// This mirrors the logic from ContentView.NotchLayout() but in a testable form.
    func computeDisplayState(from input: NotchStateInput) -> NotchDisplayState {
        // Store input for debugging
        lastInput = input

        // Priority 1: Hello animation
        if input.helloAnimationRunning {
            return .helloAnimation
        }

        // Priority 2: Open state
        if input.notchState == .open {
            return .open(view: input.currentView)
        }

        // From here, we're in closed state
        // Priority 3: Battery notification
        if input.expandingView.type == .battery &&
           input.expandingView.show &&
           input.showPowerStatusNotifications {
            return .closed(content: .batteryNotification)
        }

        // Priority 4: Inline HUD (non-music, non-battery sneak peek with inline HUD enabled)
        if input.sneakPeek.show &&
           input.showInlineHUD &&
           input.sneakPeek.type != .music &&
           input.sneakPeek.type != .battery {
            return .closed(content: .inlineHUD(
                type: input.sneakPeek.type,
                value: input.sneakPeek.value,
                icon: input.sneakPeek.icon
            ))
        }

        // Priority 5: Music Live Activity
        if (!input.expandingView.show || input.expandingView.type == .music) &&
           (input.isPlaying || !input.isPlayerIdle) &&
           input.musicLiveActivityEnabled &&
           !input.hideOnClosed {
            return .closed(content: .musicLiveActivity)
        }

        // Priority 6: Face animation (when not playing and face enabled)
        if !input.expandingView.show &&
           !input.isPlaying &&
           input.isPlayerIdle &&
           input.showNotHumanFace &&
           !input.hideOnClosed {
            return .closed(content: .face)
        }

        // Priority 7: Standard sneak peek (non-inline HUD)
        if input.sneakPeek.show &&
           !input.showInlineHUD &&
           input.sneakPeek.type != .music &&
           input.sneakPeek.type != .battery {
            return .closed(content: .sneakPeek(
                type: input.sneakPeek.type,
                value: input.sneakPeek.value,
                icon: input.sneakPeek.icon
            ))
        }

        // Priority 8: Music sneak peek (standard style)
        if input.sneakPeek.show &&
           input.sneakPeek.type == .music &&
           !input.hideOnClosed &&
           input.sneakPeekStyle == .standard {
            return .closed(content: .sneakPeek(
                type: .music,
                value: input.sneakPeek.value,
                icon: input.sneakPeek.icon
            ))
        }

        // Default: idle
        return .closed(content: .idle)
    }

    /// Update the display state and publish changes
    func update(with input: NotchStateInput) {
        let newState = computeDisplayState(from: input)
        if displayState != newState {
            displayState = newState
        }
    }

    /// Create input from current app state (convenience method)
    static func createInput(
        notchState: NotchState,
        currentView: NotchViews,
        coordinator: BoringViewCoordinator,
        musicManager: MusicManager,
        hideOnClosed: Bool
    ) -> NotchStateInput {
        NotchStateInput(
            notchState: notchState,
            currentView: currentView,
            helloAnimationRunning: coordinator.helloAnimationRunning,
            sneakPeek: coordinator.sneakPeek,
            expandingView: coordinator.expandingView,
            musicLiveActivityEnabled: coordinator.musicLiveActivityEnabled,
            isPlaying: musicManager.isPlaying,
            isPlayerIdle: musicManager.isPlayerIdle,
            hideOnClosed: hideOnClosed,
            showPowerStatusNotifications: Defaults[.showPowerStatusNotifications],
            showInlineHUD: Defaults[.inlineHUD],
            showNotHumanFace: Defaults[.showNotHumanFace],
            sneakPeekStyle: Defaults[.sneakPeekStyles]
        )
    }
}

// MARK: - Computed Properties (for ContentView compatibility)

extension NotchStateMachine {
    /// Compute the chin width based on display state.
    /// This extracts the computedChinWidth logic from ContentView.
    func computeChinWidth(
        baseWidth: CGFloat,
        displayClosedNotchHeight: CGFloat
    ) -> CGFloat {
        switch displayState {
        case .closed(let content):
            switch content {
            case .batteryNotification:
                return 640
            case .musicLiveActivity, .face:
                return baseWidth + (2 * max(0, displayClosedNotchHeight - 12) + 20)
            default:
                return baseWidth
            }
        case .open, .helloAnimation, .sneakPeek, .expanding:
            return baseWidth
        }
    }

    /// Whether the notch should show sneak peek overlay
    var shouldShowSneakPeekOverlay: Bool {
        if case .closed(let content) = displayState {
            switch content {
            case .sneakPeek, .inlineHUD:
                return true
            default:
                return false
            }
        }
        return false
    }
}
