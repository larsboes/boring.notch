//
//  BoringViewModel.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Combine
import Defaults
import SwiftUI

@MainActor
@Observable class BoringViewModel: NSObject {
    // MARK: - Dependencies (injected, not @ObservedObject to singletons)

    /// View coordinator - accessed as property, not @ObservedObject
    /// This prevents the VM from republishing on every coordinator change
    private let coordinator: BoringViewCoordinator

    /// Fullscreen media detector - accessed as property, not @ObservedObject
    private let detector: FullscreenMediaDetector

    let animationLibrary: BoringAnimations = .init()
    let animation: Animation?

    var contentType: ContentType = .normal

    // MARK: - Phase State (replaces notchState + hoverController)

    /// The current phase of the notch UI (closed, opening, open, closing)
    private(set) var phase: NotchPhase = .closed

    /// Backwards compatibility: computed notchState based on phase
    var notchState: NotchState {
        phase.isVisible ? .open : .closed
    }

    // Hover tasks for debouncing
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?

    // Hover configuration
    private let openDelay: Duration = .milliseconds(50)
    private let closeDelayNormal: Duration = .milliseconds(700)
    private var closeDelayShelf: Duration { .seconds(Defaults[.shelfHoverDelay]) }
    private var preventClose: Bool = false

    /// Manages hover zone using fixed screen coordinates (not animated view bounds)
    private let hoverZoneManager = HoverZoneManager()

    var dragDetectorTargeting: Bool = false
    var generalDropTargeting: Bool = false
    var dropZoneTargeting: Bool = false
    var dropEvent: Bool = false
    var anyDropZoneTargeting: Bool {
        dropZoneTargeting || dragDetectorTargeting || generalDropTargeting
    }
    var cancellables: Set<AnyCancellable> = []
    
    var hideOnClosed: Bool = true

    var edgeAutoOpenActive: Bool = false
    var isHoveringCalendar: Bool = false
    var isBatteryPopoverActive: Bool = false
    
    var backgroundImage: NSImage?

    var screenUUID: String? {
        didSet {
            Task { @MainActor in
                updateNotchSize()
            }
        }
    }

    var notchSize: CGSize = getClosedNotchSize()
    var closedNotchSize: CGSize = getClosedNotchSize()
    
    private let webcamService: any WebcamServiceProtocol
    var isCameraExpanded: Bool = false
    var isRequestingAuthorization: Bool = false
    
    var inactiveNotchSize: CGSize = .zero
    private var inactiveHeightUpdateTask: DispatchWorkItem?
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.notchHeightChanged, object: nil)
        // Note: cancellables will be automatically released when the object is deallocated
        // Cannot call MainActor methods from deinit
    }

    nonisolated func destroy() {
        // This method is kept for external cleanup calls if needed
        // Cancellables are automatically cancelled when the set is deallocated
    }

    private let musicService: any MusicServiceProtocol
    private let soundService: any SoundServiceProtocol
    private let dragDropService: any DragDropServiceProtocol
    var shelfService: ShelfServiceProtocol?

    // ... (rest of properties)

    /// Initialize with dependency injection.
    @MainActor
    init(
        screenUUID: String? = nil,
        coordinator: BoringViewCoordinator,
        detector: FullscreenMediaDetector,
        webcamService: any WebcamServiceProtocol,
        musicService: any MusicServiceProtocol,
        soundService: any SoundServiceProtocol,
        dragDropService: any DragDropServiceProtocol
    ) {
        self.coordinator = coordinator
        self.detector = detector
        self.webcamService = webcamService
        self.musicService = musicService
        self.soundService = soundService
        self.dragDropService = dragDropService
        self.animation = animationLibrary.animation
        
        // Shelf service will be injected via property setter
        self.shelfService = nil

        super.init()
        
        setupDragDropCallbacks()

        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize
        inactiveNotchSize = getInactiveNotchSize(screenUUID: screenUUID)

        // Initialize hover zone with screen coordinates
        hoverZoneManager.updateHoverZone(screenUUID: screenUUID)

        setupDetectorObserver()
        setupBackgroundImageObserver()
        setupNotchHeightObserver()
    }
    
    /// Convenience initializer for previews and legacy support
    @MainActor
    override convenience init() {
        let musicService = MusicService(manager: MusicManager())
        self.init(
            coordinator: BoringViewCoordinator.shared,
            detector: FullscreenMediaDetector(musicService: musicService),
            webcamService: WebcamManager(),
            musicService: musicService,
            soundService: SoundService(),
            dragDropService: DragDropService()
        )
    }
    

    
    private func setupDragDropCallbacks() {
        dragDropService.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.dragDetectorTargeting = true
                self.open()
                // Switch to shelf view when dragging over notch
                self.coordinator.currentView = .shelf
            }
        }
        
        dragDropService.onDragExitsNotchRegion = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.dragDetectorTargeting = false
                // Optional: Close notch or switch back?
                // For now, we keep it open to allow dropping
            }
        }
        
        dragDropService.startMonitoring()
    }
    
    private func setupNotchHeightObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateNotchSize()
            }
        }
    }
    
    private func updateNotchSize() {
        let newClosedSize = getClosedNotchSize(screenUUID: self.screenUUID)
        let newInactiveSize = getInactiveNotchSize(screenUUID: self.screenUUID)

        withAnimation(.smooth(duration: 0.3)) {
            self.closedNotchSize = newClosedSize
            self.inactiveNotchSize = newInactiveSize

            if self.notchState == .closed {
                self.notchSize = newClosedSize
            }

            // Update drag detector region
            if let screenFrame = getScreenFrame(self.screenUUID) {
                // Calculate notch rect in global screen coordinates
                // Notch is centered at the top of the screen
                // We use the open notch size for the hit target to make it easier to hit
                let width = openNotchSize.width
                let height = openNotchSize.height
                let x = screenFrame.midX - (width / 2)
                let y = screenFrame.maxY - height

                let region = CGRect(x: x, y: y, width: width, height: height)
                self.dragDropService.updateNotchRegion(region)
            }
        }
    }
    
    private func setupBackgroundImageObserver() {
        Defaults.publisher(.backgroundImageURL)
            .map(\.newValue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.loadBackgroundImage(from: url)
            }
            .store(in: &cancellables)
        
        if let url = Defaults[.backgroundImageURL] {
            loadBackgroundImage(from: url)
        }
    }
    
    private func loadBackgroundImage(from url: URL?) {
        guard let url = url else {
            backgroundImage = nil
            return
        }
        
        let image = NSImage(contentsOf: url)
        backgroundImage = image
    }
    
    static func copyBackgroundImageToAppStorage(sourceURL: URL) -> URL? {
        let fm = FileManager.default
        
        guard let supportDir = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        
        let targetDir = supportDir
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent("Background", isDirectory: true)
        
        do {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = targetDir.appendingPathComponent("background.\(fileExtension)")
        
        if fm.fileExists(atPath: destinationURL.path) {
            try? fm.removeItem(at: destinationURL)
        }
        
        do {
            let didStartAccessing = sourceURL.isFileURL ? sourceURL.startAccessingSecurityScopedResource() : false
            defer {
                if didStartAccessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
            
            try fm.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }
    
    private func setupDetectorObserver() {
        Task { @MainActor in
            // Observe Defaults changes
            for await _ in Defaults.updates(.hideNotchOption) {
                updateHideOnClosed()
            }
        }
        
        Task { @MainActor in
            // Poll/Observe detector status and screenUUID
            // Since we don't have a direct stream for property changes in @Observable yet without boilerplate,
            // and screenUUID changes rarely, we can use a loop with withObservationTracking or just check periodically
            // if we want to be 100% reactive.
            // However, for simplicity and robustness with @Observable:
            
            while !Task.isCancelled {
                let shouldHide = withObservationTracking {
                    let enabled = Defaults[.hideNotchOption] != .never
                    let uuid = self.screenUUID
                    let status = self.detector.fullscreenStatus
                    
                    if let uuid = uuid {
                        return enabled && (status[uuid] ?? false)
                    }
                    return false
                } onChange: {
                    Task { @MainActor in
                        // Trigger re-evaluation
                    }
                }
                
                if self.hideOnClosed != shouldHide {
                    withAnimation(.smooth) {
                        self.hideOnClosed = shouldHide
                    }
                }
                
                // Wait for a bit to avoid tight loop if onChange fires rapidly or immediately
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
    
    private func updateHideOnClosed() {
        let enabled = Defaults[.hideNotchOption] != .never
        let uuid = self.screenUUID
        let status = self.detector.fullscreenStatus
        
        let shouldHide: Bool
        if let uuid = uuid {
            shouldHide = enabled && (status[uuid] ?? false)
        } else {
            shouldHide = false
        }
        
        if self.hideOnClosed != shouldHide {
            withAnimation(.smooth) {
                self.hideOnClosed = shouldHide
            }
        }
    }




    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        
        if noNotchAndFullscreen {
            return 0
        }
        
        // Check if any live activity is active
        let isFaceActive = !musicService.playbackState.isPlaying &&
                           musicService.isPlayerIdle &&
                           Defaults[.showNotHumanFace]

        let hasActiveLiveActivity = musicService.playbackState.isPlaying ||
                                    coordinator.sneakPeek.show ||
                                    (coordinator.expandingView.show && coordinator.expandingView.type == .battery) ||
                                    isFaceActive
        
        // Use inactive height when there's no live activity
        if hasActiveLiveActivity {
            return getClosedNotchSize(screenUUID: screenUUID, hasLiveActivity: true).height
        } else {
            return inactiveNotchSize.height
        }
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    func toggleCameraPreview() {
        if isRequestingAuthorization {
            return
        }

        switch webcamService.authorizationStatus {
        case .authorized:
            if webcamService.isSessionRunning {
                webcamService.stopSession()
                isCameraExpanded = false
            } else if webcamService.cameraAvailable {
                webcamService.startSession()
                isCameraExpanded = true
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Camera Access Required"
                alert.informativeText = "Please allow camera access in System Settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }

        case .notDetermined:
            isRequestingAuthorization = true
            webcamService.checkAndRequestVideoAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isRequestingAuthorization = false
            }

        default:
            break
        }
    }
    
    // MARK: - Mouse Tracking (Phase-Based Hover)

    /// Window reference for position validation
    weak var window: NSWindow?

    /// Whether mouse is currently inside the notch region
    private(set) var isHoveringNotch: Bool = false

    /// Set the window reference for hover validation
    func setHoverWindow(_ window: NSWindow?) {
        self.window = window
    }

    // MARK: - Hover Zone Management

    /// Updates the hover zone geometry. Call when screen changes, not during animation.
    func updateHoverZone() {
        hoverZoneManager.updateHoverZone(screenUUID: screenUUID)
    }

    /// Single entry point for hover signals from TrackingAreaView.
    /// Validates actual mouse position using HoverZoneManager.
    func handleHoverSignal(_ signal: HoverSignal) {
        switch signal {
        case .entered:
            handleHoverEntered()
        case .exited:
            handleHoverExited()
        }
    }

    private func handleHoverEntered() {
        // Validate: is mouse REALLY in the hover zone?
        guard hoverZoneManager.isMouseInHoverZone() else { return }

        closeTask?.cancel()
        closeTask = nil
        isHoveringNotch = true

        // Only open if currently closed
        guard phase == .closed else { return }

        // Check if hover-to-open is enabled
        guard Defaults[.openNotchOnHover] && !coordinator.sneakPeek.show else { return }

        openTask?.cancel()
        openTask = Task { @MainActor in
            try? await Task.sleep(for: openDelay)
            guard !Task.isCancelled else { return }

            // Re-validate before opening
            if self.isHoveringNotch,
               self.hoverZoneManager.isMouseInHoverZone(),
               self.phase == .closed {
                self.open()
            }
        }
    }

    private func handleHoverExited() {
        openTask?.cancel()
        openTask = nil

        // Validate: is mouse REALLY outside the hover zone?
        guard !hoverZoneManager.isMouseInHoverZone() else { return }

        isHoveringNotch = false
        scheduleClose()
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
    private func scheduleClose() {
        // Check if close should be prevented
        let shouldPreventClose = isBatteryPopoverActive || SharingStateManager.shared.preventNotchClose
        guard !shouldPreventClose else { return }
        guard phase == .open else { return }

        closeTask?.cancel()
        closeTask = Task { @MainActor in
            let delay = coordinator.currentView == .shelf ? closeDelayShelf : closeDelayNormal
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }

            // Final validation
            let stillShouldPrevent = self.isBatteryPopoverActive || SharingStateManager.shared.preventNotchClose
            if !self.isHoveringNotch && !stillShouldPrevent && self.phase == .open {
                // Double-check mouse position using hover zone
                if !self.hoverZoneManager.isMouseInHoverZone() {
                    self.close(force: true)
                }
            }
        }
    }

    /// Setup hover controller (kept for API compatibility)
    func setupHoverController() {
        // No-op: hover logic is now inline
    }

    /// Legacy compatibility - cancel pending close
    func cancelPendingClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    func open() {
        // Guard against opening when not closed
        guard phase == .closed else { return }

        // Cancel any pending close
        closeTask?.cancel()
        closeTask = nil

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
        if SharingStateManager.shared.preventNotchClose { return }

        // Safety Check: If mouse is inside and not forced, REFUSE to close.
        if !force && isHoveringNotch && phase == .open { return }

        // Guard against closing when not open
        guard phase == .open || force else { return }

        // Cancel any pending open
        openTask?.cancel()
        openTask = nil

        // Transition to closing phase
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
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
                if self.hoverZoneManager.isMouseInHoverZone() {
                    self.isHoveringNotch = true
                    self.handleHoverEntered()
                } else {
                    self.isHoveringNotch = false
                }
            }
        }

        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false

        // Set the current view to shelf if it contains files and the user enables openShelfByDefault
        // Otherwise, if the user has not enabled openLastShelfByDefault, set the view to home
        let isShelfEmpty = shelfService?.isEmpty ?? true
        if !isShelfEmpty && Defaults[.openShelfByDefault] {
            coordinator.currentView = .shelf
        } else if !coordinator.openLastTabByDefault {
            coordinator.currentView = .home
        }
    }

    /// Sync window's isNotchOpen state with current phase
    private func syncWindowState() {
        if let boringWindow = window as? BoringNotchWindow {
            boringWindow.isNotchOpen = phase.isInteractive
        } else if let skyLightWindow = window as? BoringNotchSkyLightWindow {
            skyLightWindow.isNotchOpen = phase.isInteractive
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
