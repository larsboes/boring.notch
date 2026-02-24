//
//  AppObjectGraph.swift
//  boringNotch
//
//  Central DI root — constructs all services, coordinators, and wires dependencies.
//

import Foundation
import SwiftUI

@MainActor
final class AppObjectGraph {

    // MARK: - Core Services

    let eventBus = PluginEventBus()
    let settings: NotchSettings = DefaultsNotchSettings()
    let coordinator = BoringViewCoordinator()

    lazy var pluginManager: PluginManager = {
        PluginManager(
            services: ServiceContainer(eventBus: eventBus, settings: settings),
            eventBus: eventBus,
            appState: BoringAppState(),
            builtInPlugins: [
                MusicPlugin(),
                BatteryPlugin(),
                CalendarPlugin(),
                WeatherPlugin(),
                ShelfPlugin(),
                WebcamPlugin(),
                NotificationsPlugin(),
                ClipboardPlugin()
            ]
        )
    }()

    // MARK: - View Model

    lazy var vm: BoringViewModel = {
        BoringViewModel(
            coordinator: coordinator,
            detector: fullscreenDetector,
            webcamService: pluginManager.services.webcam,
            musicService: pluginManager.services.music,
            soundService: pluginManager.services.sound,
            dragDropService: pluginManager.services.dragDrop
        )
    }()

    // MARK: - Coordinators

    lazy var fullscreenDetector: FullscreenMediaDetector = {
        FullscreenMediaDetector(musicService: pluginManager.services.music)
    }()

    lazy var mediaKeyInterceptor: MediaKeyInterceptor = {
        MediaKeyInterceptor(
            volumeService: pluginManager.services.volume,
            brightnessService: pluginManager.services.brightness,
            keyboardBacklightService: pluginManager.services.keyboardBacklight,
            coordinator: coordinator
        )
    }()

    lazy var windowCoordinator: WindowCoordinator = {
        let wc = WindowCoordinator(
            primaryViewModel: vm,
            coordinator: coordinator,
            settings: settings,
            pluginManager: pluginManager,
            detector: fullscreenDetector
        )
        wc.onDragDetectorsNeedSetup = { [weak self] in
            self?.dragDetectionCoordinator.setupDragDetectors()
        }
        return wc
    }()

    lazy var keyboardShortcutCoordinator: KeyboardShortcutCoordinator = {
        KeyboardShortcutCoordinator(coordinator: coordinator, windowCoordinator: windowCoordinator, settings: settings)
    }()

    lazy var dragDetectionCoordinator: DragDetectionCoordinator = {
        DragDetectionCoordinator(windowCoordinator: windowCoordinator, coordinator: coordinator, settings: settings)
    }()

    // MARK: - Convenience Accessors

    var window: NSWindow? { windowCoordinator.window }
    var windows: [String: NSWindow] { windowCoordinator.windows }
    var viewModels: [String: BoringViewModel] { windowCoordinator.viewModels }

    var isScreenLocked: Bool {
        get { windowCoordinator.isScreenLocked }
        set { windowCoordinator.isScreenLocked = newValue }
    }

    // MARK: - Delegation Methods

    func adjustWindowPosition(changeAlpha: Bool = false) {
        windowCoordinator.adjustWindowPosition(changeAlpha: changeAlpha)
    }

    func cleanupWindows(shouldInvert: Bool = false) {
        windowCoordinator.cleanupWindows(shouldInvert: shouldInvert)
    }

    func setupDragDetectors() {
        dragDetectionCoordinator.setupDragDetectors()
    }

    func cleanupDragDetectors() {
        dragDetectionCoordinator.cleanupDragDetectors()
    }

    func playWelcomeSound() {
        pluginManager.services.sound.play(.welcome)
    }

    func deviceHasNotch() -> Bool {
        if #available(macOS 12.0, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Screen Lock/Unlock

    func onScreenLocked() {
        isScreenLocked = true
        if !settings.showOnLockScreen {
            cleanupWindows()
        } else {
            windowCoordinator.enableSkyLightOnAllWindows()
        }
    }

    func onScreenUnlocked() {
        isScreenLocked = false
        if !settings.showOnLockScreen {
            adjustWindowPosition(changeAlpha: true)
        } else {
            windowCoordinator.disableSkyLightOnAllWindows()
        }
    }

    // MARK: - Notification Observer Setup

    func setupNotificationObservers(
        screenConfigSelector: Selector,
        target: AnyObject
    ) -> (observers: [Any], screenLocked: Any?, screenUnlocked: Any?) {
        var observers: [Any] = []

        NotificationCenter.default.addObserver(
            target,
            selector: screenConfigSelector,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let window = self.window else { return }
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        })

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
            }
        })

        let screenLocked = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.onScreenLocked()
                }
        }

        let screenUnlocked = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.onScreenUnlocked()
                }
        }

        return (observers, screenLocked, screenUnlocked)
    }
}
