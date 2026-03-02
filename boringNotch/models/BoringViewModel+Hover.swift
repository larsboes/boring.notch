//
//  BoringViewModel+Hover.swift
//  boringNotch
//
//  Extracted hover zone management and legacy compatibility from BoringViewModel.
//

import Foundation

extension BoringViewModel {
    // MARK: - Hover Zone Management

    /// Set the window reference for hover validation
    func setHoverWindow(_ window: NSWindow?) {
        self.window = window
    }

    /// Updates the hover zone geometry. Call when screen changes, not during animation.
    func updateHoverZone() {
        hoverController.updateHoverZone(screenUUID: screenUUID)
    }

    /// Single entry point for hover signals from TrackingAreaView.
    func handleHoverSignal(_ signal: HoverSignal) {
        hoverController.handleHoverSignal(
            signal,
            currentPhase: phase,
            sneakPeekActive: coordinator.sneakPeek.show
        ) { [weak self] in
            self?.open()
        }

        // Handle exited signal for scheduling close
        if case .exited = signal {
            scheduleClose()
        }
    }

    // MARK: - Legacy Compatibility

    /// Called by TrackingAreaView when mouse enters (legacy API)
    func mouseEntered() {
        handleHoverSignal(.entered)
    }

    /// Called by TrackingAreaView when mouse exits (legacy API)
    func mouseExited() {
        handleHoverSignal(.exited)
    }

    /// Schedule a close after the appropriate delay
    func scheduleClose() {
        hoverController.scheduleClose(
            currentPhase: phase,
            currentView: coordinator.currentView
        ) { [weak self] in
            self?.close(force: true)
        }
    }

    /// Setup hover controller (kept for API compatibility)
    func setupHoverController() {
        // No-op: hover logic is now in hoverController
    }

    /// Legacy compatibility - cancel pending close
    func cancelPendingClose() {
        hoverController.cancelPendingClose()
    }
}
