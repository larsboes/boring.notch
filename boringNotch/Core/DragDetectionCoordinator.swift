//
//  DragDetectionCoordinator.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Extracted from AppDelegate - handles drag detection for opening the notch.
//

import AppKit
import Defaults

/// Coordinates drag detection to open the notch when files are dragged to the notch region.
/// Extracted from AppDelegate to improve separation of concerns.
@MainActor
final class DragDetectionCoordinator {
    // MARK: - Properties

    /// UUID -> DragDetector mapping for each screen
    private var dragDetectors: [String: DragDetector] = [:]

    /// Reference to window coordinator for accessing view models and windows
    private weak var windowCoordinator: WindowCoordinator?

    /// Reference to view coordinator
    private let coordinator: BoringViewCoordinator

    // MARK: - Initialization

    init(
        windowCoordinator: WindowCoordinator,
        coordinator: BoringViewCoordinator = .shared
    ) {
        self.windowCoordinator = windowCoordinator
        self.coordinator = coordinator
    }

    // MARK: - Setup

    /// Setup drag detectors for all relevant screens
    func setupDragDetectors() {
        cleanupDragDetectors()

        guard Defaults[.expandedDragDetection] else { return }

        if Defaults[.showOnAllDisplays] {
            for screen in NSScreen.screens {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = windowCoordinator?.window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    // MARK: - Per-Screen Setup

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }

        let screenFrame = screen.frame
        let notchHeight = openNotchSize.height
        let notchWidth = openNotchSize.width

        // Create notch region at the top-center of the screen where an open notch would occupy
        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )

        let detector = DragDetector(notchRegion: notchRegion)

        detector.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }

        dragDetectors[uuid] = detector
        detector.startMonitoring()
    }

    // MARK: - Drag Handling

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard let uuid = screen.displayUUID,
              let windowCoordinator = windowCoordinator else { return }

        if Defaults[.showOnAllDisplays] {
            if let viewModel = windowCoordinator.viewModels[uuid] {
                viewModel.open()
                coordinator.currentView = .shelf
            }
        } else {
            if let windowScreen = windowCoordinator.window?.screen, screen == windowScreen {
                windowCoordinator.primaryViewModel.open()
                coordinator.currentView = .shelf
            }
        }
    }

    // MARK: - Cleanup

    func cleanupDragDetectors() {
        dragDetectors.values.forEach { detector in
            detector.stopMonitoring()
        }
        dragDetectors.removeAll()
    }
}
