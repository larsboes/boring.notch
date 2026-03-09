//
//  NotchGestureCoordinator.swift
//  boringNotch
//

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
        /// Threshold crossed — trigger open. Associated velocity is the translation magnitude at trigger time.
        case triggerOpen(velocity: CGFloat)
        /// Threshold crossed — trigger close.
        case triggerClose
    }

    /// Process a downward pan gesture (used to open the notch).
    static func handleDown(
        translation: CGFloat,
        phase: NSEvent.Phase,
        notchState: NotchState,
        sensitivity: CGFloat
    ) -> GestureResult {
        guard notchState == .closed else { return .reset }

        if phase == .ended {
            return .reset
        }

        let progress = (translation / sensitivity) * 20

        if translation > sensitivity {
            return .triggerOpen(velocity: translation)
        }

        return .progress(progress)
    }

    /// Process an upward pan gesture (used to close the notch).
    static func handleUp(
        translation: CGFloat,
        phase: NSEvent.Phase,
        notchState: NotchState,
        isHoveringCalendar: Bool,
        preventClose: Bool,
        sensitivity: CGFloat
    ) -> GestureResult {
        guard notchState == .open && !isHoveringCalendar else { return .reset }

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
