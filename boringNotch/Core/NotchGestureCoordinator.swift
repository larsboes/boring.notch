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
        /// Threshold crossed — trigger open. Associated velocity is pts/s at trigger time.
        case triggerOpen(velocity: CGFloat)
        /// Threshold crossed — trigger close.
        case triggerClose
    }

    // Velocity tracking state
    private static var prevTranslation: CGFloat = 0
    private static var prevTimestamp: Date?

    private static func computeVelocity(translation: CGFloat) -> CGFloat {
        let now = Date()
        defer {
            prevTranslation = translation
            prevTimestamp = now
        }
        guard let prev = prevTimestamp else { return 0 }
        let dt = now.timeIntervalSince(prev)
        guard dt > 0.001 else { return 0 }
        return (translation - prevTranslation) / CGFloat(dt)
    }

    private static func resetTracking() {
        prevTranslation = 0
        prevTimestamp = nil
    }

    /// Process a downward pan gesture (used to open the notch).
    static func handleDown(
        translation: CGFloat,
        phase: NSEvent.Phase,
        notchState: NotchState,
        sensitivity: CGFloat
    ) -> GestureResult {
        guard notchState == .closed else {
            resetTracking()
            return .reset
        }

        if phase == .ended {
            resetTracking()
            return .reset
        }

        let velocity = computeVelocity(translation: translation)
        let progress = (translation / sensitivity) * 20

        if translation > sensitivity {
            let v = velocity
            resetTracking()
            return .triggerOpen(velocity: v)
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
