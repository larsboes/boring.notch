//
//  BoringViewCoordinator.swift
//  boringNotch
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
import Defaults
import SwiftUI

enum SneakContentType {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case battery
    case download
}

struct sneakPeek {
    var show: Bool = false
    var type: SneakContentType = .music
    var value: CGFloat = 0
    var icon: String = ""
}

struct SharedSneakPeek: Codable {
    var show: Bool
    var type: String
    var value: String
    var icon: String
}

enum BrowserType {
    case chromium
    case safari
}

struct ExpandedItem {
    var show: Bool = false
    var type: SneakContentType = .battery
    var value: CGFloat = 0
    var browser: BrowserType = .chromium
}

@MainActor
@Observable class BoringViewCoordinator {
    static let shared = BoringViewCoordinator()

    var currentView: NotchViews = .home
    var helloAnimationRunning: Bool = false
    private var sneakPeekDispatch: DispatchWorkItem?
    private var expandingViewDispatch: DispatchWorkItem?
    private var hudEnableTask: Task<Void, Never>?

    // Defaults properties
    var firstLaunch: Bool {
        get { Defaults[.firstLaunch] }
        set { Defaults[.firstLaunch] = newValue }
    }
    
    var showWhatsNew: Bool {
        get { Defaults[.showWhatsNew] }
        set { Defaults[.showWhatsNew] = newValue }
    }
    
    var musicLiveActivityEnabled: Bool {
        get { Defaults[.musicLiveActivityEnabled] }
        set { Defaults[.musicLiveActivityEnabled] = newValue }
    }
    
    var currentMicStatus: Bool {
        get { Defaults[.currentMicStatus] }
        set { Defaults[.currentMicStatus] = newValue }
    }

    var alwaysShowTabs: Bool {
        get { Defaults[.alwaysShowTabs] }
        set { Defaults[.alwaysShowTabs] = newValue }
    }
    
    var openLastTabByDefault: Bool {
        get { Defaults[.openLastTabByDefault] }
        set { Defaults[.openLastTabByDefault] = newValue }
    }
    
    var hudReplacement: Bool {
        get { Defaults[.hudReplacement] }
        set { Defaults[.hudReplacement] = newValue }
    }
    
    // Legacy storage for migration
    // @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?
    
    // New UUID-based storage
    var preferredScreenUUID: String? {
        get { Defaults[.preferredScreenUUID] }
        set { Defaults[.preferredScreenUUID] = newValue }
    }

    var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    var optionKeyPressed: Bool = true
    private var accessibilityObserver: Any?
    private var hudReplacementCancellable: AnyCancellable?
    private var musicSneakPeekCancellable: AnyCancellable?

    private init() {
        // Subscribe to MusicManager's sneak peek requests
        // This replaces the direct coupling where MusicManager called coordinator methods
        setupMusicSneakPeekSubscription()
        
        // Perform migration from name-based to UUID-based storage
        let legacyName = UserDefaults.standard.string(forKey: "preferred_screen_name")
        
        if preferredScreenUUID == nil, let legacyName = legacyName {
            // Try to find screen by name and migrate to UUID
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
                NSLog("✅ Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                // Fallback to main screen if legacy screen not found
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("⚠️ Could not find display named '\(legacyName)', falling back to main screen")
            }
            // Clear legacy value after migration
            UserDefaults.standard.removeObject(forKey: "preferred_screen_name")
        } else if preferredScreenUUID == nil {
            // No legacy value, use main screen
            preferredScreenUUID = NSScreen.main?.displayUUID
        }
        
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
        // Observe changes to accessibility authorization and react accordingly
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.accessibilityAuthorizationChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if Defaults[.hudReplacement] {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
            }
        }

        // Observe changes to hudReplacement
        hudReplacementCancellable = Defaults.publisher(.hudReplacement)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.hudEnableTask?.cancel()
                    self.hudEnableTask = nil

                    if change.newValue {
                        self.hudEnableTask = Task { @MainActor in
                            let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                            if Task.isCancelled { return }

                            if granted {
                                await MediaKeyInterceptor.shared.start()
                            } else {
                                Defaults[.hudReplacement] = false
                            }
                        }
                    } else {
                        MediaKeyInterceptor.shared.stop()
                    }
                }
            }
            
        // Observe changes to alwaysShowTabs
        Task { @MainActor in
            for await value in Defaults.updates(.alwaysShowTabs) {
                if !value {
                    openLastTabByDefault = false
                    if ShelfStateViewModel.shared.isEmpty || !Defaults[.openShelfByDefault] {
                        currentView = .home
                    }
                }
            }
        }
        
        // Observe changes to openLastTabByDefault
        Task { @MainActor in
            for await value in Defaults.updates(.openLastTabByDefault) {
                if value {
                    alwaysShowTabs = true
                }
            }
        }
        
        // Observe changes to preferredScreenUUID
        Task { @MainActor in
            for await uuid in Defaults.updates(.preferredScreenUUID) {
                if let uuid = uuid {
                    selectedScreenUUID = uuid
                }
                NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
            }
        }

        Task { @MainActor in
            helloAnimationRunning = firstLaunch
            
            // Failsafe: Ensure hello animation doesn't run forever
            if helloAnimationRunning {
                try? await Task.sleep(for: .seconds(10))
                if helloAnimationRunning {
                    helloAnimationRunning = false
                }
            }

            if Defaults[.hudReplacement] {
                let authorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
                if !authorized {
                    Defaults[.hudReplacement] = false
                } else {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
            }
        }
    }
    
    @objc func sneakPeekEvent(_ notification: Notification) {
        let decoder = JSONDecoder()
        if let decodedData = try? decoder.decode(
            SharedSneakPeek.self, from: notification.userInfo?.first?.value as! Data) {
            let contentType =
                decodedData.type == "brightness"
                ? SneakContentType.brightness
                : decodedData.type == "volume"
                    ? SneakContentType.volume
                    : decodedData.type == "backlight"
                        ? SneakContentType.backlight
                        : decodedData.type == "mic"
                            ? SneakContentType.mic : SneakContentType.brightness

            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            let value = CGFloat((formatter.number(from: decodedData.value) ?? 0.0).floatValue)
            let icon = decodedData.icon

            print("Decoded: \(decodedData), Parsed value: \(value)")

            toggleSneakPeek(status: decodedData.show, type: contentType, value: value, icon: icon)

        } else {
            print("Failed to decode JSON data")
        }
    }

    func toggleSneakPeek(
        status: Bool, type: SneakContentType, duration: TimeInterval = 1.5, value: CGFloat = 0,
        icon: String = ""
    ) {
        sneakPeekDuration = duration == 1.5 ? Defaults[.sneakPeakDuration] : duration
        if type != .music {
            // close()
            if !Defaults[.hudReplacement] {
                return
            }
        }
        Task { @MainActor in
            withAnimation(.smooth) {
                self.sneakPeek.show = status
                self.sneakPeek.type = type
                self.sneakPeek.value = value
                self.sneakPeek.icon = icon
            }
        }

        if type == .mic {
            currentMicStatus = value == 1
        }
    }

    private var sneakPeekDuration: TimeInterval = Defaults[.sneakPeakDuration]
    private var sneakPeekTask: Task<Void, Never>?

    // Helper function to manage sneakPeek timer using Swift Concurrency
    private func scheduleSneakPeekHide(after duration: TimeInterval) {
        sneakPeekTask?.cancel()

        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    self.toggleSneakPeek(status: false, type: .music)
                    self.sneakPeekDuration = Defaults[.sneakPeakDuration]
                }
            }
        }
    }

    var sneakPeek: sneakPeek = .init() {
        didSet {
            if sneakPeek.show {
                scheduleSneakPeekHide(after: sneakPeekDuration)
            } else {
                sneakPeekTask?.cancel()
            }
        }
    }

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat = 0,
        browser: BrowserType = .chromium
    ) {
        Task { @MainActor in
            withAnimation(.smooth) {
                self.expandingView.show = status
                self.expandingView.type = type
                self.expandingView.value = value
                self.expandingView.browser = browser
            }
        }
    }

    private var expandingViewTask: Task<Void, Never>?

    var expandingView: ExpandedItem = .init() {
        didSet {
            if expandingView.show {
                expandingViewTask?.cancel()
                let duration: TimeInterval = (expandingView.type == .download ? 2 : 3)
                let currentType = expandingView.type
                expandingViewTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(duration))
                    guard let self = self, !Task.isCancelled else { return }
                    self.toggleExpandingView(status: false, type: currentType)
                }
            } else {
                expandingViewTask?.cancel()
            }
        }
    }
    
    func showEmpty() {
        currentView = .home
    }

    // MARK: - Music Manager Integration

    /// Subscribe to MusicManager's sneak peek requests.
    /// This maintains separation of concerns: MusicManager publishes requests,
    /// coordinator handles the UI updates.
    private func setupMusicSneakPeekSubscription() {
        musicSneakPeekCancellable = MusicManager.shared.sneakPeekPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                guard let self = self else { return }
                if request.style == .standard {
                    self.toggleSneakPeek(status: true, type: request.type)
                } else {
                    self.toggleExpandingView(status: true, type: request.type)
                }
            }
    }
}
