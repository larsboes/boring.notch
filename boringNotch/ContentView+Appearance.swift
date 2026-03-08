//
//  ContentView+Appearance.swift
//  boringNotch
//
//  Extracted from ContentView — appearance calculations and view builders.
//

import SwiftUI

// MARK: - Appearance Calculations

extension ContentView {
    var isNotchHeightZero: Bool { vm.effectiveClosedNotchHeight == 0 }

    var displayClosedNotchHeight: CGFloat { isNotchHeightZero ? 10 : vm.effectiveClosedNotchHeight }

    var animationProgress: CGFloat {
        // Robustness: Prefer explicitly managed shellProgress, 
        // but fallback to actual height-based calculation if we detect a discrepancy.
        // This prevents "sharp corners on a tall notch" (the black rectangle glitch).
        let currentHeight = vm.notchSize.height
        let openHeight = openNotchSize.height
        let closedHeight = displayClosedNotchHeight
        
        let heightProgress = max(0, min(1, (currentHeight - closedHeight) / (openHeight - closedHeight)))
        
        // If shellProgress is stuck at 0 but height is > 50% expanded, something is wrong.
        // Use the higher of the two to ensure corners are ALWAYS rounded when notch is large.
        return max(vm.shellAnimationProgress, heightProgress)
    }

    func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    /// Smooth Hermite interpolation — maps progress from edge0→edge1 to 0→1 with ease-in/out.
    /// Use for content that should start appearing partway through the animation.
    /// Example: `smoothstep(0.3, 0.8, animationProgress)` → content fades 0→1 between 30-80% of shell animation.
    func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    /// Content-specific progress — decoupled from shell spring.
    /// Driven by vm.contentRevealProgress which has independent animation curves:
    /// - Open: easeOut(0.28s) with 0.08s delay — shell leads, content follows
    /// - Close: easeIn(0.15s) — content exits before shell finishes contracting
    /// Apple Dynamic Island pattern: shape morphs alone, then content reveals.
    var contentProgress: CGFloat {
        vm.contentRevealProgress
    }

    var cornerRadiusScaleFactor: CGFloat? {
        guard settings.cornerRadiusScaling else { return nil }
        let effectiveHeight = displayClosedNotchHeight
        guard effectiveHeight > 0 else { return nil }
        return effectiveHeight / 38.0
    }

    var topCornerRadius: CGFloat {
        let baseClosedTop = cornerRadiusInsets.closed.top
        let closedRadius: CGFloat
        if let scaleFactor = cornerRadiusScaleFactor {
            closedRadius = max(0, baseClosedTop * scaleFactor)
        } else {
            closedRadius = displayClosedNotchHeight > 0 ? baseClosedTop : 0
        }
        return lerp(closedRadius, cornerRadiusInsets.opened.top, animationProgress)
    }

    var bottomCornerRadius: CGFloat {
        let baseClosedBottom = cornerRadiusInsets.closed.bottom
        let closedRadius: CGFloat
        if let scaleFactor = cornerRadiusScaleFactor {
            closedRadius = max(0, baseClosedBottom * scaleFactor)
        } else {
            closedRadius = displayClosedNotchHeight > 0 ? baseClosedBottom : 0
        }
        return lerp(closedRadius, cornerRadiusInsets.opened.bottom, animationProgress)
    }

    var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    var computedChinWidth: CGFloat {
        if vm.phase.isVisible {
            // During opening, open, and closing phases, we follow the animated notch size.
            // This prevents the "huge black rectangle" during closing transitions.
            return vm.notchSize.width
        }

        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && settings.showPowerStatusNotifications {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicService.playbackState.isPlaying || !musicService.isPlayerIdle)
            && settings.musicLiveActivityEnabled && !vm.hideOnClosed {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicService.playbackState.isPlaying && musicService.isPlayerIdle) && settings.showNotHumanFace
            && !vm.hideOnClosed {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }
}

// MARK: - Gesture Handling

extension ContentView {
    func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        let result = NotchGestureCoordinator.handleDown(
            translation: translation, phase: phase, notchState: vm.notchState,
            sensitivity: settings.gestureSensitivity
        )
        applyGestureResult(result, openAction: { doOpen() })
    }

    func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        let result = NotchGestureCoordinator.handleUp(
            translation: translation, phase: phase,
            notchState: vm.notchState,
            isHoveringCalendar: vm.isHoveringCalendar,
            preventClose: pluginManager?.services.sharing.preventNotchClose ?? false,
            sensitivity: settings.gestureSensitivity
        )
        applyGestureResult(result, closeAction: { vm.close(force: true) })
    }

    func applyGestureResult(
        _ result: NotchGestureCoordinator.GestureResult,
        openAction: (() -> Void)? = nil,
        closeAction: (() -> Void)? = nil
    ) {
        switch result {
        case .progress(let value):
            withAnimation(StandardAnimations.interactive) { gestureProgress = value }
        case .reset:
            withAnimation(StandardAnimations.interactive) { gestureProgress = .zero }
        case .triggerOpen:
            if settings.enableHaptics { haptics.toggle() }
            withAnimation(StandardAnimations.interactive) { gestureProgress = .zero }
            openAction?()
        case .triggerClose:
            gestureProgress = .zero
            closeAction?()
            if settings.enableHaptics { haptics.toggle() }
        }
    }
}
