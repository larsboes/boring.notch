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
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        updaterController = SPUStandardUpdaterController(
            startingUpdater: !isRunningTests, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)

        if !isRunningTests {
            SettingsWindowController.shared.setUpdaterController(updaterController)
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
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
        .environment(\.pluginManager, appDelegate.graph.pluginManager)
    }
}

// MARK: - AppDelegate (Lifecycle Only)

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let graph = AppObjectGraph()

    var statusItem: NSStatusItem?
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var observers: [Any] = []

    // MARK: - Legacy Accessors

    var pluginManager: PluginManager { graph.pluginManager }
    var coordinator: BoringViewCoordinator { graph.coordinator }
    var vm: BoringViewModel { graph.vm }
    var window: NSWindow? { graph.window }
    var windows: [String: NSWindow] { graph.windows }
    var viewModels: [String: BoringViewModel] { graph.viewModels }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        Task {
            await pluginManager.activateEnabledPlugins()
        }

        coordinator.configure(
            eventBus: pluginManager.eventBus,
            mediaKeyInterceptor: graph.mediaKeyInterceptor
        )

        let result = graph.setupNotificationObservers(
            screenConfigSelector: #selector(screenConfigurationDidChange),
            target: self
        )
        observers = result.observers
        screenLockedObserver = result.screenLocked
        screenUnlockedObserver = result.screenUnlocked

        graph.keyboardShortcutCoordinator.setupKeyboardShortcuts()
        syncNotchHeightIfNeeded()
        graph.adjustWindowPosition(changeAlpha: true)
        graph.setupDragDetectors()

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

        graph.playWelcomeSound()
        previousScreens = NSScreen.screens
    }

    func applicationWillTerminate(_ notification: Notification) {
        pluginManager.services.shelf.flushSync()

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

        graph.cleanupDragDetectors()
        graph.cleanupWindows()
        graph.keyboardShortcutCoordinator.cancelPendingTasks()

        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()

        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - Screen Configuration

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
                syncNotchHeightIfNeeded()
                self?.graph.cleanupWindows()
                self?.graph.adjustWindowPosition()
                self?.graph.setupDragDetectors()
            }
        }
    }

    // MARK: - Onboarding

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

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}
