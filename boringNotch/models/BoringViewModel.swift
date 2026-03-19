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
    let coordinator: any ViewCoordinating
    private let detector: FullscreenMediaDetector
    let settings: NotchViewModelSettings
    let displaySettings: any DisplaySettings
    let hoverController: NotchHoverController
    let sizeCalculator: NotchSizeCalculator
    let observerSetup: NotchObserverSetup

    let animationLibrary: BoringAnimations = .init()
    let animation: Animation?

    var contentType: ContentType = .normal

    var phase: NotchPhase = .closed {
        didSet {
            guard phase != oldValue else { return }
            
            syncAnimationState(animated: true)
            
            // Back off background services when closed to save battery
            if phase.isVisible {
                // Resume polling if available
                if let bgBattery = services.battery as? BackgroundServiceRestartable {
                    bgBattery.startMonitoring()
                }
                if let bgBluetooth = services.bluetoothManager as? BackgroundServiceRestartable {
                    bgBluetooth.startMonitoring()
                }
            } else {
                // Halt heavy polling and timers
                if let bgBattery = services.battery as? BackgroundServiceRestartable {
                    bgBattery.stopMonitoring()
                }
                if let bgBluetooth = services.bluetoothManager as? BackgroundServiceRestartable {
                    bgBluetooth.stopMonitoring()
                }
            }
        }
    }
    /// Decoupled content reveal progress (0→1).
    /// Animated independently from the shell spring so content can lead/lag the shell.
    var contentRevealProgress: CGFloat = 0

    /// Shell expansion progress (0→1).
    /// Driven by StandardAnimations.open/close to ensure smooth corner radius transitions.
    var shellAnimationProgress: CGFloat = 0

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
    var hideOnClosedDebounceTask: Task<Void, Never>?

    /// Optional plugin-requested height override for closed notch (e.g. teleprompter needs double height)
    var pluginPreferredHeight: CGFloat?

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

    var isCameraExpanded: Bool = false
    var isRequestingAuthorization: Bool = false

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.notchHeightChanged, object: nil)
    }

    nonisolated func destroy() {
        // This method is kept for external cleanup calls if needed
    }

    let services: any NotchServiceProvider

    var shelfService: ShelfServiceProtocol?

    weak var window: NSWindow?
    var isHoveringNotch: Bool {
        hoverController.isHoveringNotch
    }

    // MARK: - Initialization

    @MainActor
    init(
        screenUUID: String? = nil,
        coordinator: any ViewCoordinating,
        detector: FullscreenMediaDetector,
        services: any NotchServiceProvider,
        settings: NotchViewModelSettings? = nil,
        displaySettings: any DisplaySettings
    ) {
        self.coordinator = coordinator
        self.detector = detector
        self.services = services
        // settings must be provided; nil fallback only for secondary window clones
        self.settings = settings ?? DefaultNotchViewModelSettings(source: MockNotchSettings())
        self.displaySettings = displaySettings
        self.animation = animationLibrary.animation

        self.hoverController = NotchHoverController(settings: self.settings, displaySettings: displaySettings)
        self.sizeCalculator = NotchSizeCalculator(settings: self.settings, displaySettings: displaySettings, musicService: services.music)
        self.observerSetup = NotchObserverSetup(settings: self.settings, detector: detector)
        self.shelfService = nil

        super.init()
        
        let preventCloseThunk: @MainActor () -> Bool = { [weak self] in
            return self?.services.sharing.preventNotchClose ?? false
        }
        hoverController.shouldPreventClose = preventCloseThunk
        configureHoverCallbacks()
        setupDragDropCallbacks()

        self.screenUUID = screenUUID
        sizeCalculator.notchSize = getClosedNotchSize(settings: displaySettings, screenUUID: screenUUID)
        sizeCalculator.closedNotchSize = sizeCalculator.notchSize
        sizeCalculator.inactiveNotchSize = getInactiveNotchSize(settings: displaySettings, screenUUID: screenUUID)

        hoverController.updateHoverZone(screenUUID: screenUUID)

        setupDetectorObserver()
        setupBackgroundImageObserver()
        setupNotchHeightObserver()
        setupIntentObservers()
    }

    private func setupIntentObservers() {
        NotificationCenter.default.addObserver(
            forName: .openNotchIntent,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.open() }
        }

        NotificationCenter.default.addObserver(
            forName: .closeNotchIntent,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.close(force: true) }
        }
    }

    @MainActor
    override convenience init() {
        let mockSettings = MockNotchSettings()
        let musicService = MusicService(manager: MusicManager(settings: mockSettings))
        
        // Use a lightweight mock container for previews
        let mockServices = ServiceContainer(
            eventBus: PluginEventBus(),
            settings: mockSettings
        )
        
        self.init(
            coordinator: BoringViewCoordinator(settings: mockSettings, xpcHelper: XPCHelperClient.shared),
            detector: FullscreenMediaDetector(musicService: musicService, settings: mockSettings),
            services: mockServices,
            displaySettings: mockSettings
        )
    }

    private func setupDragDropCallbacks() {
        services.dragDrop.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.dragDetectorTargeting = true
                self.open()
                self.coordinator.currentView = .shelf
            }
        }

        services.dragDrop.onDragExitsNotchRegion = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.dragDetectorTargeting = false
            }
        }

        services.dragDrop.startMonitoring()
    }

    func syncWindowState() {
        if let boringWindow = window as? BoringNotchWindow {
            boringWindow.isNotchOpen = phase.isInteractive
        } else if let skyLightWindow = window as? BoringNotchSkyLightWindow {
            skyLightWindow.isNotchOpen = phase.isInteractive
        }
    }

    /// Ensures progress variables match the current phase.
    /// Acts as a safety fallback for interrupted animations.
    /// Skips .closing/.opening transitions — those are driven by the explicit
    /// withAnimation blocks in open()/close() and must not be overridden here.
    func syncAnimationState(animated: Bool = false) {
        // Only sync for terminal states (.open, .closed).
        // Transition states (.opening, .closing) are managed by their animation blocks.
        guard !phase.isTransitioning else { return }

        let targetProgress: CGFloat = phase.isVisible ? 1 : 0

        if animated {
            let animation = phase.isVisible ? StandardAnimations.open : StandardAnimations.close
            withAnimation(animation) {
                self.shellAnimationProgress = targetProgress
                self.contentRevealProgress = targetProgress
            }
        } else {
            self.shellAnimationProgress = targetProgress
            self.contentRevealProgress = targetProgress
        }
    }

    static func copyBackgroundImageToAppStorage(sourceURL: URL) -> URL? {
        NotchObserverSetup.copyBackgroundImageToAppStorage(sourceURL: sourceURL)
    }
}
