//
//  NotchGestureCoordinator.swift
//  boringNotch
//

import Defaults
import SwiftUI

/// Encapsulates pan gesture logic for opening and closing the notch.
/// Calculates gesture progress and triggers open/close actions based on
/// velocity thresholds defined in user settings.
@MainActor
struct NotchGestureCoordinator {
    /// Result of processing a gesture event.
    enum GestureResult {
        /// Update visual progress only (no state change).
        case progress(CGFloat)
        /// Gesture ended — reset progress to zero.
        case reset
        /// Threshold crossed — trigger open.
        case triggerOpen
        /// Threshold crossed — trigger close.
        case triggerClose
    }

    /// Process a downward pan gesture (used to open the notch).
    /// - Parameters:
    ///   - translation: Cumulative gesture translation in points.
    ///   - phase: Current NSEvent phase.
    ///   - notchState: Current notch state.
    /// - Returns: What action the caller should take.
    static func handleDown(
        translation: CGFloat,
        phase: NSEvent.Phase,
        notchState: NotchState
    ) -> GestureResult {
        guard notchState == .closed else { return .reset }

        if phase == .ended {
            return .reset
        }

        let sensitivity = Defaults[.gestureSensitivity]
        let progress = (translation / sensitivity) * 20

        if translation > sensitivity {
            return .triggerOpen
        }

        return .progress(progress)
    }

    /// Process an upward pan gesture (used to close the notch).
    /// - Parameters:
    ///   - translation: Cumulative gesture translation in points.
    ///   - phase: Current NSEvent phase.
    ///   - notchState: Current notch state.
    ///   - isHoveringCalendar: Whether the calendar hover is active.
    ///   - preventClose: Whether sharing prevents closing.
    /// - Returns: What action the caller should take.
    static func handleUp(
        translation: CGFloat,
        phase: NSEvent.Phase,
        notchState: NotchState,
        isHoveringCalendar: Bool,
        preventClose: Bool
    ) -> GestureResult {
        guard notchState == .open && !isHoveringCalendar else { return .reset }

        let sensitivity = Defaults[.gestureSensitivity]

        if translation > sensitivity {
            return preventClose ? .progress(0) : .triggerClose
        }

        let progress = (translation / sensitivity) * -20

        if phase == .ended {
            return .reset
        }

        return .progress(progress)
    }
}
