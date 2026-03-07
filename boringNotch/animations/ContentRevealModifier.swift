//
//  ContentRevealModifier.swift
//  boringNotch
//
//  Choreographed content reveal tied to continuous animation progress.
//  Content grows out of the notch center with staggered timing.
//

import SwiftUI

// MARK: - Content Reveal Modifier

struct ContentRevealModifier: ViewModifier {
    /// Continuous progress from 0 (closed) to 1 (fully open)
    let progress: CGFloat
    /// Stagger index — higher indices appear later
    let staggerIndex: Int
    /// Whether to apply blur (disable for camera to avoid render errors)
    let useBlur: Bool

    /// Per-element stagger offset (each index delays the start by this amount of progress)
    private let staggerStep: CGFloat = 0.08

    /// This element's effective progress, accounting for stagger
    private var elementProgress: CGFloat {
        let offset = CGFloat(staggerIndex) * staggerStep
        let adjusted = (progress - offset) / (1.0 - offset)
        return max(0, min(1, adjusted))
    }

    /// Smooth Hermite interpolation
    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }

    func body(content: Content) -> some View {
        let opacity = smoothstep(elementProgress)
        let scale = 0.92 + 0.08 * smoothstep(elementProgress)
        let yOffset = (1.0 - smoothstep(elementProgress)) * -4.0
        let blurRadius = useBlur ? (1.0 - elementProgress) * 12.0 : 0

        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .offset(y: yOffset)
            .blur(radius: blurRadius)
    }
}

// MARK: - View Extension

extension View {
    /// Choreographed content reveal tied to animation progress.
    /// - Parameters:
    ///   - progress: Continuous 0→1 from contentProgress environment value
    ///   - staggerIndex: Element order (0 = first to appear)
    ///   - useBlur: Set false for camera views to avoid render errors
    func contentReveal(progress: CGFloat, staggerIndex: Int, useBlur: Bool = true) -> some View {
        modifier(ContentRevealModifier(progress: progress, staggerIndex: staggerIndex, useBlur: useBlur))
    }
}
