//
//  BoringViewModel.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//  Refactored: Thin orchestrator using extracted controllers
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

    /// Settings provider (injected, replaces direct Defaults access)
    private let settings: NotchViewModelSettings

    /// Display settings for sizing calculations
    private let displaySettings: any DisplaySettings

    /// Hover controller for mouse interaction
    private let hoverController: NotchHoverController

    /// Size calculator for notch dimensions
    private let sizeCalculator: NotchSizeCalculator

    /// Observer setup manager
    private let observerSetup: NotchObserverSetup

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

    var dragDetectorTargeting: Bool = false
    var generalDropTargeting: Bool = false
    var dropZoneTargeting: Bool = false
    var dropEvent: Bool = false
    var anyDropZoneTargeting: Bool {
        dropZoneTargeting || dragDetectorTargeting || generalDropTargeting
    }

    var hideOnClosed: Bool = true

    var edgeAutoOpenActive: Bool = false
    var isHoveringCalendar: Bool = false

    var isBatteryPopoverActive: Bool = false {
        didSet {
            hoverController.isBatteryPopoverActive = isBatteryPopoverActive
        }
    }

    var backgroundImage: NSImage?

    var screenUUID: String? {
        didSet {
            Task { @MainActor in
                updateNotchSize()
            }
        }
    }

    // Notch size properties delegated to sizeCalculator
    var notchSize: CGSize {
        get { sizeCalculator.notchSize }
        set { sizeCalculator.notchSize = newValue }
    }

    var closedNotchSize: CGSize {
        get { sizeCalculator.closedNotchSize }
        set { sizeCalculator.closedNotchSize = newValue }
    }

    var inactiveNotchSize: CGSize {
        get { sizeCalculator.inactiveNotchSize }
        set { sizeCalculator.inactiveNotchSize = newValue }
    }

    private let webcamService: any WebcamServiceProtocol
    var isCameraExpanded: Bool = false
    var isRequestingAuthorization: Bool = false

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.notchHeightChanged, object: nil)
    }

    nonisolated func destroy() {
        // This method is kept for external cleanup calls if needed
    }

    private let musicService: any MusicServiceProtocol
    private let soundService: any SoundServiceProtocol
    private let dragDropService: any DragDropServiceProtocol
    var shelfService: ShelfServiceProtocol?

    /// Window reference for position validation
    weak var window: NSWindow?

    /// Whether mouse is currently inside the notch region (delegated to hoverController)
    var isHoveringNotch: Bool {
        hoverController.isHoveringNotch
    }

    // MARK: - Initialization

    /// Initialize with dependency injection.
    @MainActor
    init(
        screenUUID: String? = nil,
        coordinator: BoringViewCoordinator,
        detector: FullscreenMediaDetector,
        webcamService: any WebcamServiceProtocol,
        musicService: any MusicServiceProtocol,
        soundService: any SoundServiceProtocol,
        dragDropService: any DragDropServiceProtocol,
        settings: NotchViewModelSettings = DefaultNotchViewModelSettings(),
        displaySettings: any DisplaySettings = DefaultsNotchSettings.shared
    ) {
        self.coordinator = coordinator
        self.detector = detector
        self.webcamService = webcamService
        self.musicService = musicService
        self.soundService = soundService
        self.dragDropService = dragDropService
        self.settings = settings
        self.displaySettings = displaySettings
        self.animation = animationLibrary.animation

        // Initialize extracted components
        self.hoverController = NotchHoverController(settings: settings, displaySettings: displaySettings)
        self.sizeCalculator = NotchSizeCalculator(settings: settings, displaySettings: displaySettings, musicService: musicService)
        self.observerSetup = NotchObserverSetup(settings: settings, detector: detector)

        // Shelf service will be injected via property setter
        self.shelfService = nil

        super.init()

        // Configure hover controller's close prevention check
        hoverController.shouldPreventClose = { [weak self] in
            // Replace SharingStateManager.shared.preventNotchClose
            SharingStateManager.shared.preventNotchClose
        }

        setupDragDropCallbacks()

        self.screenUUID = screenUUID
        sizeCalculator.notchSize = getClosedNotchSize(settings: displaySettings, screenUUID: screenUUID)
        sizeCalculator.closedNotchSize = sizeCalculator.notchSize
        sizeCalculator.inactiveNotchSize = getInactiveNotchSize(settings: displaySettings, screenUUID: screenUUID)

        // Initialize hover zone with screen coordinates
        hoverController.updateHoverZone(screenUUID: screenUUID)

        setupDetectorObserver()
        setupBackgroundImageObserver()
        setupNotchHeightObserver()
    }

    /// Convenience initializer for previews only
    @MainActor
    override convenience init() {
        let mockSettings = MockNotchSettings()
        let musicService = MusicService(manager: MusicManager(settings: mockSettings))
        self.init(
            coordinator: BoringViewCoordinator(),
            detector: FullscreenMediaDetector(musicService: musicService, settings: mockSettings),
            webcamService: WebcamManager(),
            musicService: musicService,
            soundService: SoundService(),
            dragDropService: DragDropService()
        )
    }

    // MARK: - Setup Methods

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
        let result = sizeCalculator.updateNotchSize(
            screenUUID: self.screenUUID,
            currentState: self.notchState
        )

        withAnimation(.smooth(duration: 0.3)) {
            if result.shouldUpdateNotchSize {
                self.notchSize = result.closedSize
            }

            // Update drag detector region
            if let screenFrame = getScreenFrame(self.screenUUID) {
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
        observerSetup.setupBackgroundImageObserver { [weak self] image in
            self?.backgroundImage = image
        }
    }

    private func setupDetectorObserver() {
        observerSetup.setupDetectorObserver(screenUUID: screenUUID) { [weak self] shouldHide in
            guard let self = self else { return }
            if self.hideOnClosed != shouldHide {
                withAnimation(.smooth) {
                    self.hideOnClosed = shouldHide
                }
            }
        }
    }

    // MARK: - Computed Properties

    var effectiveClosedNotchHeight: CGFloat {
        sizeCalculator.effectiveClosedNotchHeight(
            screenUUID: screenUUID,
            hideOnClosed: hideOnClosed,
            sneakPeekActive: coordinator.sneakPeek.show,
            expandingViewActive: coordinator.expandingView.show,
            expandingViewType: coordinator.expandingView.type,
            coordinator: coordinator
        )
    }

    var chinHeight: CGFloat {
        sizeCalculator.chinHeight(
            screenUUID: screenUUID,
            notchState: notchState,
            effectiveClosedHeight: effectiveClosedNotchHeight
        )
    }

    // MARK: - Camera Methods

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
    private func scheduleClose() {
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

    // MARK: - Open/Close Methods

    func open() {
        // Guard against opening when not closed
        guard phase == .closed else { return }

        // Cancel any pending close
        hoverController.cancelPendingClose()

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
        // NOTE: Still uses SharingStateManager.shared until full refactor
        if SharingStateManager.shared.preventNotchClose { return }

        // Safety Check: If mouse is inside and not forced, REFUSE to close.
        if !force && isHoveringNotch && phase == .open { return }

        // Guard against closing when not open
        guard phase == .open || force else { return }

        // Cancel any pending open
        hoverController.cancelPendingOpen()

        // Transition to closing phase
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            self.notchSize = getClosedNotchSize(settings: self.displaySettings, screenUUID: self.screenUUID)
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
                if self.hoverController.isMouseInHoverZone() {
                    self.handleHoverSignal(.entered)
                }
            }
        }

        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false

        // Set the current view to shelf if it contains files and the user enables openShelfByDefault
        let isShelfEmpty = shelfService?.isEmpty ?? true
        if !isShelfEmpty && settings.openShelfByDefault {
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

    // MARK: - Static Utility Methods

    /// Copy background image to app storage
    static func copyBackgroundImageToAppStorage(sourceURL: URL) -> URL? {
        NotchObserverSetup.copyBackgroundImageToAppStorage(sourceURL: sourceURL)
    }
}
