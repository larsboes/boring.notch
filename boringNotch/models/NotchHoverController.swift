//
//  NotchHoverController.swift
//  boringNotch
//
//  Extracted from BoringViewModel - handles hover interactions and open/close scheduling
//

import SwiftUI

/// Controller for managing hover-based notch interactions
@MainActor
@Observable class NotchHoverController {
    // MARK: - Dependencies

    /// Settings provider (injected, not direct Defaults access)
    private let settings: NotchViewModelSettings

    /// Manages hover zone using fixed screen coordinates
    private let hoverZoneManager = HoverZoneManager()

    /// Closure to check if close should be prevented (replaces SharingStateManager.shared)
    var shouldPreventClose: () -> Bool = { false }

    /// Whether battery popover is active (prevents close)
    var isBatteryPopoverActive: Bool = false

    // MARK: - State

    /// Whether mouse is currently inside the notch region
    private(set) var isHoveringNotch: Bool = false

    // Hover tasks for debouncing
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?

    // Hover configuration
    private let openDelay: Duration = .milliseconds(50)
    private let closeDelayNormal: Duration = .milliseconds(700)
    private var closeDelayShelf: Duration { .seconds(settings.shelfHoverDelay) }

    // MARK: - Initialization

    init(settings: NotchViewModelSettings) {
        self.settings = settings
    }

    // MARK: - Hover Zone Management

    /// Updates the hover zone geometry. Call when screen changes, not during animation.
    func updateHoverZone(screenUUID: String?) {
        hoverZoneManager.updateHoverZone(screenUUID: screenUUID)
    }

    /// Single entry point for hover signals from TrackingAreaView.
    /// Validates actual mouse position using HoverZoneManager.
    func handleHoverSignal(
        _ signal: HoverSignal,
        currentPhase: NotchPhase,
        sneakPeekActive: Bool,
        onOpen: @escaping () -> Void
    ) {
        switch signal {
        case .entered:
            handleHoverEntered(
                currentPhase: currentPhase,
                sneakPeekActive: sneakPeekActive,
                onOpen: onOpen
            )
        case .exited:
            handleHoverExited()
        }
    }

    private func handleHoverEntered(
        currentPhase: NotchPhase,
        sneakPeekActive: Bool,
        onOpen: @escaping () -> Void
    ) {
        // Validate: is mouse REALLY in the hover zone?
        guard hoverZoneManager.isMouseInHoverZone() else { return }

        closeTask?.cancel()
        closeTask = nil
        isHoveringNotch = true

        // Only open if currently closed
        guard currentPhase == .closed else { return }

        // Check if hover-to-open is enabled
        guard settings.openNotchOnHover && !sneakPeekActive else { return }

        openTask?.cancel()
        openTask = Task { @MainActor in
            try? await Task.sleep(for: openDelay)
            guard !Task.isCancelled else { return }

            // Re-validate before opening
            if self.isHoveringNotch,
               self.hoverZoneManager.isMouseInHoverZone(),
               currentPhase == .closed {
                onOpen()
            }
        }
    }

    private func handleHoverExited() {
        openTask?.cancel()
        openTask = nil

        // Validate: is mouse REALLY outside the hover zone?
        guard !hoverZoneManager.isMouseInHoverZone() else { return }

        isHoveringNotch = false
    }

    /// Schedule a close after the appropriate delay
    func scheduleClose(
        currentPhase: NotchPhase,
        currentView: NotchViews,
        onClose: @escaping () -> Void
    ) {
        // Check if close should be prevented
        let shouldPrevent = isBatteryPopoverActive || shouldPreventClose()
        guard !shouldPrevent else { return }
        guard currentPhase == .open else { return }

        closeTask?.cancel()
        closeTask = Task { @MainActor in
            let delay = currentView == .shelf ? closeDelayShelf : closeDelayNormal
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }

            // Final validation
            let stillShouldPrevent = self.isBatteryPopoverActive || self.shouldPreventClose()
            if !self.isHoveringNotch && !stillShouldPrevent && currentPhase == .open {
                // Double-check mouse position using hover zone
                if !self.hoverZoneManager.isMouseInHoverZone() {
                    onClose()
                }
            }
        }
    }

    /// Cancel pending close task
    func cancelPendingClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    /// Cancel pending open task
    func cancelPendingOpen() {
        openTask?.cancel()
        openTask = nil
    }

    /// Check if mouse is in hover zone
    func isMouseInHoverZone() -> Bool {
        hoverZoneManager.isMouseInHoverZone()
    }
}
