//
//  NotchPhaseController.swift
//  boringNotch
//
//  Extracted from BoringViewModel - handles notch phase transitions (open/close)
//

import SwiftUI

/// Controller for managing notch phase transitions
@MainActor
@Observable class NotchPhaseController {
    // MARK: - Dependencies

    /// Hover controller for canceling pending operations
    private let hoverController: NotchHoverController

    /// Music service for force updates on open
    private let musicService: any MusicServiceProtocol

    /// Animation library for animations
    private let animationLibrary: BoringAnimations

    // MARK: - Callbacks

    /// Called when notch size should be updated
    var onNotchSizeChanged: (CGSize) -> Void = { _ in }

    /// Called when closed notch size should be updated
    var onClosedNotchSizeChanged: (CGSize) -> Void = { _ in }

    /// Get the current screen UUID
    var getScreenUUID: () -> String? = { nil }

    /// Check if mouse is currently hovering over notch
    var isHoveringNotch: () -> Bool = { false }

    /// Check if close should be prevented (e.g., sharing in progress)
    var preventClose: () -> Bool = { false }

    /// Callback when close occurs - handles side effects
    var onClose: () -> Void = { }

    /// Callback to sync window state with phase
    var syncWindow: (NotchPhase) -> Void = { _ in }

    /// Callback when mouse is still in zone after close animation
    var onMouseStillInZone: () -> Void = { }

    // MARK: - State

    /// The current phase of the notch UI (closed, opening, open, closing)
    private(set) var phase: NotchPhase = .closed

    // MARK: - Initialization

    init(
        hoverController: NotchHoverController,
        musicService: any MusicServiceProtocol,
        animationLibrary: BoringAnimations
    ) {
        self.hoverController = hoverController
        self.musicService = musicService
        self.animationLibrary = animationLibrary
    }

    // MARK: - Configuration

    func configure(
        onNotchSizeChanged: @escaping (CGSize) -> Void,
        onClosedNotchSizeChanged: @escaping (CGSize) -> Void,
        getScreenUUID: @escaping () -> String?,
        isHoveringNotch: @escaping () -> Bool,
        preventClose: @escaping () -> Bool,
        onClose: @escaping () -> Void,
        syncWindow: @escaping (NotchPhase) -> Void,
        onMouseStillInZone: @escaping () -> Void
    ) {
        self.onNotchSizeChanged = onNotchSizeChanged
        self.onClosedNotchSizeChanged = onClosedNotchSizeChanged
        self.getScreenUUID = getScreenUUID
        self.isHoveringNotch = isHoveringNotch
        self.preventClose = preventClose
        self.onClose = onClose
        self.syncWindow = syncWindow
        self.onMouseStillInZone = onMouseStillInZone
    }

    // MARK: - Open/Close Methods

    func open() {
        // Guard against opening when not closed
        guard phase == .closed else { return }

        // Cancel any pending close
        hoverController.cancelPendingClose()

        // Transition to opening phase
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            onNotchSizeChanged(openNotchSize)
            self.phase = .opening
        }

        // Complete the opening after animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if self.phase == .opening {
                self.phase = .open
                self.syncWindow(self.phase)
            }
        }

        // Force music information update when notch is opened
        musicService.forceUpdate()
    }

    func close(force: Bool = false) {
        // Do not close while a share picker or sharing service is active
        if preventClose() { return }

        // Safety Check: If mouse is inside and not forced, REFUSE to close.
        if !force && isHoveringNotch() && phase == .open { return }

        // Guard against closing when not open
        guard phase == .open || force else { return }

        // Cancel any pending open
        hoverController.cancelPendingOpen()

        let screenUUID = getScreenUUID()
        let closedSize = getClosedNotchSize(screenUUID: screenUUID)

        // Transition to closing phase
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            onNotchSizeChanged(closedSize)
            onClosedNotchSizeChanged(closedSize)
            self.phase = .closing
        }

        // Complete the closing after animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if self.phase == .closing {
                self.phase = .closed
                self.syncWindow(self.phase)

                // Check if mouse is still in hover zone and should reopen
                if self.hoverController.isMouseInHoverZone() {
                    self.onMouseStillInZone()
                }
            }
        }

        // Trigger close side effects
        onClose()
    }

    func closeHello() {
        Task { @MainActor in
            withAnimation(animationLibrary.animation) {
                // Note: coordinator.helloAnimationRunning = false is handled via callback
                close()
            }
        }
    }
}
