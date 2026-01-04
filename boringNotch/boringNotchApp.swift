//
//  boringNotchApp.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI

/// Sparkle user driver delegate to handle gentle reminders for background updates
final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // No-op: Let Sparkle handle showing updates normally
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        // No-op: User has acknowledged the update
    }

    func standardUserDriverWillFinishUpdateSession() {
        // No-op: Update session is finishing
    }
}

@main
struct DynamicNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon
    @Environment(\.openWindow) var openWindow

    let updaterController: SPUStandardUpdaterController
    private let userDriverDelegate = SparkleUserDriverDelegate()

    init() {
        // Skip heavy initialization when running as test host
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        updaterController = SPUStandardUpdaterController(
            startingUpdater: !isRunningTests, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)

        // Initialize the settings window controller with the updater controller
        // Skip when running tests to avoid view instantiation that requires BoringViewModel
        if !isRunningTests {
            SettingsWindowController.shared.setUpdaterController(updaterController)
        }
    }

    /// Check if running as a test host
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        // Skip MenuBarExtra when running as test host to avoid SwiftUI initialization issues
        // FIXME: This if-else block causes a build error with SceneBuilder.
        // if isRunningTests {
        //     Settings {
        //         EmptyView()
        //     }
        // } else {
            MenuBarExtra("boring.notch", systemImage: "sparkle", isInserted: $showMenuBarIcon) {
                Button("Settings") {
                    SettingsWindowController.shared.showWindow()
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                CheckForUpdatesView(updater: updaterController.updater)
                Divider()
                Button("Restart Boring Notch") {
                    ApplicationRelauncher.restart()
                }
                Button("Quit", role: .destructive) {
                    NSApplication.shared.terminate(self)
                }
                .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
            }
            .environment(\.pluginManager, appDelegate.pluginManager)
        // }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Plugin System
    
    lazy var pluginManager: PluginManager = {
        PluginManager(
            services: ServiceContainer(),
            eventBus: PluginEventBus(),
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

    // MARK: - Coordinators (Phase 3 refactoring)
    
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

    /// Manages window creation, positioning, and multi-display support
    private lazy var windowCoordinator: WindowCoordinator = {
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

    /// Manages keyboard shortcuts
    private lazy var keyboardShortcutCoordinator: KeyboardShortcutCoordinator = {
        KeyboardShortcutCoordinator(coordinator: coordinator, windowCoordinator: windowCoordinator)
    }()

    /// Manages drag detection for opening notch
    private lazy var dragDetectionCoordinator: DragDetectionCoordinator = {
        DragDetectionCoordinator(windowCoordinator: windowCoordinator, coordinator: coordinator)
    }()

    // MARK: - Legacy Properties (to be migrated)

    var statusItem: NSStatusItem?
    
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
    
    var coordinator = BoringViewCoordinator.shared
    var quickShareService = QuickShareService.shared
    var settings: NotchSettings = DefaultsNotchSettings()
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var observers: [Any] = []

    // MARK: - Computed Properties (delegate to coordinators)

    var window: NSWindow? {
        get { windowCoordinator.window }
        set { /* Read-only, managed by WindowCoordinator */ }
    }

    var windows: [String: NSWindow] {
        windowCoordinator.windows
    }

    var viewModels: [String: BoringViewModel] {
        windowCoordinator.viewModels
    }

    private var isScreenLocked: Bool {
        get { windowCoordinator.isScreenLocked }
        set { windowCoordinator.isScreenLocked = newValue }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush debounced shelf persistence to avoid losing recent changes
        pluginManager.services.shelf.flushSync()
        
        // Deactivate plugins
        Task {
            await pluginManager.deactivateAllPlugins()
        }

        NotificationCenter.default.removeObserver(self)
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
        pluginManager.services.music.destroy()

        // Cleanup via coordinators
        dragDetectionCoordinator.cleanupDragDetectors()
        windowCoordinator.cleanupWindows()
        keyboardShortcutCoordinator.cancelPendingTasks()

        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()

        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        if !Defaults[.showOnLockScreen] {
            windowCoordinator.cleanupWindows()
        } else {
            windowCoordinator.enableSkyLightOnAllWindows()
        }
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        if !Defaults[.showOnLockScreen] {
            windowCoordinator.adjustWindowPosition(changeAlpha: true)
        } else {
            windowCoordinator.disableSkyLightOnAllWindows()
        }
    }

    // MARK: - Methods delegated to coordinators

    private func cleanupWindows(shouldInvert: Bool = false) {
        windowCoordinator.cleanupWindows(shouldInvert: shouldInvert)
    }

    private func setupDragDetectors() {
        dragDetectionCoordinator.setupDragDetectors()
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip heavy initialization when running as test host
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        
        // Activate plugins
        Task {
            await pluginManager.activateEnabledPlugins()
        }
        
        // Configure coordinator with dependencies
        coordinator.configure(
            eventBus: pluginManager.eventBus,
            mediaKeyInterceptor: mediaKeyInterceptor
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
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

        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenLocked(notification)
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenUnlocked(notification)
                }
        }

        // Setup keyboard shortcuts via coordinator
        keyboardShortcutCoordinator.setupKeyboardShortcuts()

        // Sync notch height with real value on app launch if mode is matchRealNotchSize
        syncNotchHeightIfNeeded()

        // WindowCoordinator handles both single and multi-display window creation
        adjustWindowPosition(changeAlpha: true)

        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow()
            }
        } else if pluginManager.services.music.isNowPlayingDeprecated
            && Defaults[.mediaController] == .nowPlaying {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .musicPermission)
            }
        }
        
        // Play sound on every launch as requested
        playWelcomeSound()

        previousScreens = NSScreen.screens
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

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame.debugDescription }) != Set(previousScreens?.map { $0.frame.debugDescription } ?? [])

        previousScreens = currentScreens

        if screensChanged {
            DispatchQueue.main.async { [weak self] in
                // Sync notch height with real value if mode is matchRealNotchSize
                syncNotchHeightIfNeeded()
                
                self?.cleanupWindows()
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        windowCoordinator.adjustWindowPosition(changeAlpha: changeAlpha)
    }

    @objc func togglePopover(_ sender: Any?) {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }

    @objc func showMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func quitAction() {
        NSApplication.shared.terminate(self)
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    onFinish: {
                        window.orderOut(nil)
//                        NSApp.setActivationPolicy(.accessory)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")

            onboardingWindowController = NSWindowController(window: window)
        }

//        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}
