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
    // MARK: - Dependencies
    let coordinator: BoringViewCoordinator
    private let detector: FullscreenMediaDetector
    let settings: NotchViewModelSettings
    let displaySettings: any DisplaySettings
    let hoverController: NotchHoverController
    private let sizeCalculator: NotchSizeCalculator
    private let observerSetup: NotchObserverSetup

    let animationLibrary: BoringAnimations = .init()
    let animation: Animation?

    var contentType: ContentType = .normal

    // MARK: - Phase State (replaces notchState + hoverController)

    /// The current phase of the notch UI (closed, opening, open, closing)
    var phase: NotchPhase = .closed

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

    let webcamService: any WebcamServiceProtocol
    var isCameraExpanded: Bool = false
    var isRequestingAuthorization: Bool = false

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.notchHeightChanged, object: nil)
    }

    nonisolated func destroy() {
        // This method is kept for external cleanup calls if needed
    }

    let musicService: any MusicServiceProtocol
    private let soundService: any SoundServiceProtocol
    private let dragDropService: any DragDropServiceProtocol
    let sharingService: any SharingServiceProtocol
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
        sharingService: any SharingServiceProtocol,
        settings: NotchViewModelSettings? = nil,
        displaySettings: any DisplaySettings = DefaultsNotchSettings.shared
    ) {
        self.coordinator = coordinator
        self.detector = detector
        self.webcamService = webcamService
        self.musicService = musicService
        self.soundService = soundService
        self.dragDropService = dragDropService
        self.sharingService = sharingService
        self.settings = settings ?? DefaultNotchViewModelSettings()
        self.displaySettings = displaySettings
        self.animation = animationLibrary.animation

        // Initialize extracted components
        self.hoverController = NotchHoverController(settings: self.settings, displaySettings: displaySettings)
        self.sizeCalculator = NotchSizeCalculator(settings: self.settings, displaySettings: displaySettings, musicService: musicService)
        self.observerSetup = NotchObserverSetup(settings: self.settings, detector: detector)

        // Shelf service will be injected via property setter
        self.shelfService = nil

        super.init()

        // Configure hover controller's close prevention check
        hoverController.shouldPreventClose = { [weak self] in
            self?.sharingService.preventNotchClose ?? false
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
            dragDropService: DragDropService(),
            sharingService: SharingStateManager()
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

    /// Sync window's isNotchOpen state with current phase
    func syncWindowState() {
        if let boringWindow = window as? BoringNotchWindow {
            boringWindow.isNotchOpen = phase.isInteractive
        } else if let skyLightWindow = window as? BoringNotchSkyLightWindow {
            skyLightWindow.isNotchOpen = phase.isInteractive
        }
    }

    // MARK: - Static Utility Methods

    /// Copy background image to app storage
    static func copyBackgroundImageToAppStorage(sourceURL: URL) -> URL? {
        NotchObserverSetup.copyBackgroundImageToAppStorage(sourceURL: sourceURL)
    }
}
