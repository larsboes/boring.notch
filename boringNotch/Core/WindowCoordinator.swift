//
//  WindowCoordinator.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Extracted from AppDelegate - handles window creation, positioning, and multi-display support.
//

import AppKit
import Combine
import Defaults
import SwiftUI

/// Coordinates window management for the notch across single and multiple displays.
/// Extracted from AppDelegate to improve separation of concerns.
@MainActor
final class WindowCoordinator {
    // MARK: - Properties

    /// Single-display mode window
    private(set) var window: NSWindow?

    /// Multi-display mode: UUID -> NSWindow mapping
    private(set) var windows: [String: NSWindow] = [:]

    /// Multi-display mode: UUID -> BoringViewModel mapping
    private(set) var viewModels: [String: BoringViewModel] = [:]

    /// Primary view model for single-display mode
    let primaryViewModel: BoringViewModel

    /// Reference to view coordinator
    private let coordinator: BoringViewCoordinator

    /// Track screen lock state
    var isScreenLocked: Bool = false

    /// Observer for window screen changes
    private var windowScreenDidChangeObserver: Any?

    /// Callback when drag detectors need to be reconfigured
    var onDragDetectorsNeedSetup: (() -> Void)?

    // MARK: - Initialization

    init(
        primaryViewModel: BoringViewModel,
        coordinator: BoringViewCoordinator = .shared
    ) {
        self.primaryViewModel = primaryViewModel
        self.coordinator = coordinator
    }

    // MARK: - Window Lifecycle

    /// Clean up all windows
    func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !Defaults[.showOnAllDisplays] : Defaults[.showOnAllDisplays]

        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
        } else if let window = window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            if let obs = windowScreenDidChangeObserver {
                NotificationCenter.default.removeObserver(obs)
                windowScreenDidChangeObserver = nil
            }
            self.window = nil
        }
    }

    // MARK: - Window Creation

    /// Create a notch window for a specific screen
    func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]

        let window = BoringNotchSkyLightWindow(
            contentRect: rect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Enable SkyLight only when screen is locked
        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        window.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )

        window.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        // Observe when the window's screen changes
        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onDragDetectorsNeedSetup?()
            }
        }

        return window
    }

    // MARK: - Window Positioning

    /// Position a window on a specific screen
    func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha {
            window.alphaValue = 0
        }

        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            )
        )
        window.alphaValue = 1
    }

    /// Adjust window positions based on current display configuration
    func adjustWindowPosition(changeAlpha: Bool = false) {
        if Defaults[.showOnAllDisplays] {
            adjustMultiDisplayWindows(changeAlpha: changeAlpha)
        } else {
            adjustSingleDisplayWindow(changeAlpha: changeAlpha)
        }
    }

    // MARK: - Multi-Display Support

    private func adjustMultiDisplayWindows(changeAlpha: Bool) {
        let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

        // Remove windows for screens that no longer exist
        for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
            if let window = windows[uuid] {
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
                windows.removeValue(forKey: uuid)
                viewModels.removeValue(forKey: uuid)
            }
        }

        // Create or update windows for all screens
        for screen in NSScreen.screens {
            guard let uuid = screen.displayUUID else { continue }

            if windows[uuid] == nil {
                let viewModel = BoringViewModel(screenUUID: uuid)
                let window = createBoringNotchWindow(for: screen, with: viewModel)

                windows[uuid] = window
                viewModels[uuid] = viewModel
            }

            if let window = windows[uuid], let viewModel = viewModels[uuid] {
                positionWindow(window, on: screen, changeAlpha: changeAlpha)

                if viewModel.notchState == .closed {
                    viewModel.close()
                }
            }
        }
    }

    private func adjustSingleDisplayWindow(changeAlpha: Bool) {
        let selectedScreen: NSScreen

        if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
            coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
            selectedScreen = preferredScreen
        } else if Defaults[.automaticallySwitchDisplay], let mainScreen = NSScreen.main,
                  let mainUUID = mainScreen.displayUUID {
            coordinator.selectedScreenUUID = mainUUID
            selectedScreen = mainScreen
        } else {
            if let window = window {
                window.alphaValue = 0
            }
            return
        }

        primaryViewModel.screenUUID = selectedScreen.displayUUID
        primaryViewModel.notchSize = getClosedNotchSize(screenUUID: selectedScreen.displayUUID)

        if window == nil {
            window = createBoringNotchWindow(for: selectedScreen, with: primaryViewModel)
        }

        if let window = window {
            positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)

            if primaryViewModel.notchState == .closed {
                primaryViewModel.close()
            }
        }
    }

    // MARK: - SkyLight Window Support (Lock Screen)

    func enableSkyLightOnAllWindows() {
        if Defaults[.showOnAllDisplays] {
            windows.values.forEach { window in
                if let skyWindow = window as? BoringNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? BoringNotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }

    func disableSkyLightOnAllWindows() {
        // Delay disabling SkyLight to avoid flicker during unlock transition
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                if Defaults[.showOnAllDisplays] {
                    self.windows.values.forEach { window in
                        if let skyWindow = window as? BoringNotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? BoringNotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }

    // MARK: - ViewModel Access

    /// Get the view model for a specific screen UUID
    func viewModel(for screenUUID: String) -> BoringViewModel? {
        if Defaults[.showOnAllDisplays] {
            return viewModels[screenUUID]
        } else {
            return primaryViewModel
        }
    }

    /// Get the view model for the screen containing a point
    func viewModel(at point: NSPoint) -> BoringViewModel {
        if Defaults[.showOnAllDisplays] {
            for screen in NSScreen.screens {
                if screen.frame.contains(point) {
                    if let uuid = screen.displayUUID, let screenViewModel = viewModels[uuid] {
                        return screenViewModel
                    }
                }
            }
        }
        return primaryViewModel
    }
}
