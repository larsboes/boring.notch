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
        let closedWidth = vm.closedNotchSize.width
        let openWidth = openNotchSize.width
        let currentWidth = vm.notchSize.width

        guard openWidth > closedWidth else { return 0 }

        let progress = (currentWidth - closedWidth) / (openWidth - closedWidth)
        return max(0, min(1, progress))
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

    /// Content-specific progress — shell-first timeline.
    /// Shell expands first → content fades in after shell is visibly expanding → controls last.
    /// Apple Dynamic Island pattern: shape morphs alone, then content reveals.
    var contentProgress: CGFloat {
        let p = animationProgress
        // Content starts at 30% of shell expansion and reaches full at 90%.
        // The 30% delay creates a visible "shell leads" effect.
        return smoothstep(0.30, 0.90, p)
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
