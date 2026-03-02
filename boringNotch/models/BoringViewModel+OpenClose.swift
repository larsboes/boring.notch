//
//  BoringViewModel+OpenClose.swift
//  boringNotch
//
//  Extracted open/close lifecycle methods from BoringViewModel.
//

import SwiftUI

extension BoringViewModel {
    func open() {
        // Guard against opening when not closed
        guard phase == .closed else { return }

        // Cancel any pending close
        hoverController.cancelPendingClose()

        // Transition to opening phase
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.notchSize = openNotchSize
            self.phase = .opening
        }

        // Complete the opening after animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if self.phase == .opening {
                self.phase = .open
                self.syncWindowState()
            }
        }

        // Force music information update when notch is opened
        musicService.forceUpdate()
    }

    func close(force: Bool = false) {
        // Do not close while a share picker or sharing service is active
        if sharingService.preventNotchClose { return }

        // Safety Check: If mouse is inside and not forced, REFUSE to close.
        if !force && isHoveringNotch && phase == .open { return }

        // Guard against closing when not open
        guard phase == .open || force else { return }

        // Cancel any pending open
        hoverController.cancelPendingOpen()

        // Transition to closing phase
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            self.notchSize = getClosedNotchSize(settings: self.displaySettings, screenUUID: self.screenUUID)
            self.closedNotchSize = self.notchSize
            self.phase = .closing
        }

        // Complete the closing after animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if self.phase == .closing {
                self.phase = .closed
                self.syncWindowState()

                // Check if mouse is still in hover zone and should reopen
                if self.hoverController.isMouseInHoverZone() {
                    self.handleHoverSignal(.entered)
                }
            }
        }

        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false

        // Set the current view to shelf if it contains files and the user enables openShelfByDefault
        let isShelfEmpty = shelfService?.isEmpty ?? true
        if !isShelfEmpty && settings.openShelfByDefault {
            coordinator.currentView = .shelf
        } else if !coordinator.openLastTabByDefault {
            coordinator.currentView = .home
        }
    }

    func closeHello() {
        Task { @MainActor in
            withAnimation(animationLibrary.animation) {
                coordinator.helloAnimationRunning = false
                close()
            }
        }
    }
}
