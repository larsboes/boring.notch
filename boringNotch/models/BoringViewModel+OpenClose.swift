//
//  BoringViewModel+OpenClose.swift
//  boringNotch
//
//  Extracted open/close lifecycle methods from BoringViewModel.
//

import SwiftUI

extension BoringViewModel {
    func open() {
        // Allow opening if closed OR if we are currently closing (interrupt)
        guard phase == .closed || phase == .closing else { return }

        hoverController.cancelPendingClose()

        // Shell expands (spring)
        withAnimation(StandardAnimations.open) {
            self.notchSize = openNotchSize
            self.phase = .opening
            self.shellAnimationProgress = 1
        } completion: {
            guard self.phase == .opening else { return }
            self.phase = .open
            self.hoverController.setNotchOpen(true)
            self.syncWindowState()
            self.startHoverHeartbeat()
        }

        // Content reveals independently — shell leads, content follows
        withAnimation(StandardAnimations.contentReveal) {
            self.contentRevealProgress = 1
        }

        services.music.forceUpdate()
    }

    func close(force: Bool = false) {
        if services.sharing.preventNotchClose { return }
        if !force && isHoveringNotch && phase == .open { return }
        // Allow closing if open OR if we are currently opening (interrupt)
        guard phase == .open || phase == .opening || force else { return }

        hoverController.cancelPendingOpen()
        hoverController.setNotchOpen(false)
        stopHoverHeartbeat()

        // Reset transient state before animation starts
        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false

        // Capture the target closed size BEFORE mutating phase.
        // effectiveClosedNotchSize depends on current state (music, hideOnClosed, etc.)
        // and must be read while those are still stable.
        let targetClosedSize = self.effectiveClosedNotchSize
        // closedNotchSize is the BASE physical notch width (no ears).
        // MusicLiveActivity uses it for the middle spacer between album art and spectrum.
        let baseClosedSize = getClosedNotchSize(settings: self.displaySettings, screenUUID: self.screenUUID)

        // Content and Shell exit together for a unified, clean contraction
        // Unified animation block ensures all properties settle on the same frame.
        withAnimation(StandardAnimations.close) {
            self.contentRevealProgress = 0
            self.shellAnimationProgress = 0
            self.notchSize = targetClosedSize
            self.closedNotchSize = baseClosedSize
            self.phase = .closing
        } completion: {
            guard self.phase == .closing else { return }
            self.phase = .closed
            self.syncWindowState()

            if self.hoverController.isMouseInHoverZone() {
                self.handleHoverSignal(.entered)
            }
        }
        
        // --- Safety Watchdog ---
        // If SwiftUI's completion block fails to fire (race condition), 
        // this background task ensures the phase eventually settles.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if self.phase == .closing {
                self.phase = .closed
                self.syncWindowState()
                self.syncAnimationState(animated: false)
            }
        }

        // Restore default view
        let isShelfEmpty = shelfService?.isEmpty ?? true
        if !isShelfEmpty && settings.openShelfByDefault {
            coordinator.currentView = .shelf
        } else if !coordinator.openLastTabByDefault {
            coordinator.currentView = .home
        }
    }

    func closeHello() {
        Task { @MainActor in
            self.contentRevealProgress = 0
            withAnimation(StandardAnimations.close) {
                coordinator.helloAnimationRunning = false
                close()
            }
        }
    }
}
