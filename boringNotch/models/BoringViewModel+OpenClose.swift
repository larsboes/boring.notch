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

        // Content and Shell exit together for a unified, clean contraction
        // Unified animation block ensures all properties settle on the same frame.
        withAnimation(StandardAnimations.close) {
            self.contentRevealProgress = 0
            self.shellAnimationProgress = 0
            self.notchSize = getClosedNotchSize(settings: self.displaySettings, screenUUID: self.screenUUID)
            self.closedNotchSize = self.notchSize
            self.phase = .closing
        } completion: {
            guard self.phase == .closing else { return }
            self.phase = .closed
            self.syncWindowState()

            if self.hoverController.isMouseInHoverZone() {
                self.handleHoverSignal(.entered)
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
