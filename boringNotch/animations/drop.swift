//
//  drop.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on  04/08/24.
//

import Foundation
import SwiftUI

// MARK: - Standardized Animations
/// Centralized animation definitions for consistent UI behavior across the app.
enum StandardAnimations {
    /// Interactive spring for responsive UI (used for notch interactions)
    /// Tuned for snappier feedback during gestures and hover
    static let interactive = Animation.interactiveSpring(
        response: 0.32,        // Faster response for immediate feedback
        dampingFraction: 0.82, // Slightly higher damping to reduce oscillation
        blendDuration: 0
    )

    /// Spring animation for opening the notch
    /// Subtle bounce for a polished feel
    static let open = Animation.spring(
        response: 0.38,
        dampingFraction: 0.78,
        blendDuration: 0.1
    )
    /// Estimated settle duration for the open animation
    static let openDuration: Duration = .milliseconds(400)

    /// Spring animation for closing the notch
    /// Quick and decisive with slight softness
    static let close = Animation.spring(
        response: 0.35,
        dampingFraction: 0.92,
        blendDuration: 0.08
    )
    /// Estimated settle duration for the close animation
    static let closeDuration: Duration = .milliseconds(350)

    /// Bouncy spring for playful animations
    @available(macOS 14.0, *)
    static var bouncy: Animation {
        Animation.spring(.bouncy(duration: 0.4))
    }

    /// Smooth animation for general transitions
    static let smooth = Animation.smooth

    /// Timing curve fallback for older macOS versions
    static let timingCurve = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)

    /// Organic timing curve for the hello animation
    static let hello = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 3.0)

    // MARK: - Content Transitions

    /// Animation for content appearing (fade in with scale)
    static let contentAppear = Animation.easeOut(duration: 0.22)

    /// Animation for content disappearing (quick fade out)
    static let contentDisappear = Animation.easeIn(duration: 0.15)

    /// Staggered animation for sequential content reveals
    /// - Parameter index: The index of the element in the sequence
    /// - Returns: Animation with appropriate delay for staggered effect
    static func staggered(index: Int) -> Animation {
        Animation.spring(response: 0.3, dampingFraction: 0.85)
            .delay(Double(index) * 0.04)
    }
}

@Observable
@MainActor
public final class BoringAnimations {
    var notchStyle: Style = .notch
    
    init() {
        self.notchStyle = .notch
    }
    
    var animation: Animation {
        if #available(macOS 14.0, *), notchStyle == .notch {
            StandardAnimations.bouncy
        } else {
            StandardAnimations.timingCurve
        }
    }

}
