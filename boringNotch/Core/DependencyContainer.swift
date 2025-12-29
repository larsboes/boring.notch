//
//  DependencyContainer.swift
//  boringNotch
//
//  Created as part of Phase 1 architectural refactoring.
//  Centralizes singleton access without breaking existing code.
//

import Foundation

/// Centralized container for all application dependencies.
/// This acts as a facade over existing singletons, enabling future migration
/// to proper dependency injection without breaking changes.
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Core Coordinators

    var viewCoordinator: BoringViewCoordinator { BoringViewCoordinator.shared }

    // MARK: - Managers

    var musicManager: MusicManager { MusicManager.shared }
    var brightnessManager: BrightnessManager { BrightnessManager.shared }
    var volumeManager: VolumeManager { VolumeManager.shared }
    var webcamManager: WebcamManager { WebcamManager.shared }
    var weatherManager: WeatherManager { WeatherManager.shared }
    var calendarManager: CalendarManager { CalendarManager.shared }
    var notesManager: NotesManager { NotesManager.shared }
    var clipboardManager: ClipboardManager { ClipboardManager.shared }
    var notchFaceManager: NotchFaceManager { NotchFaceManager.shared }
    var notchSpaceManager: NotchSpaceManager { NotchSpaceManager.shared }
    var bluetoothManager: BluetoothManager { BluetoothManager.shared }
    var notificationCenterManager: NotificationCenterManager { NotificationCenterManager.shared }

    // MARK: - ViewModels

    var batteryViewModel: BatteryStatusViewModel { BatteryStatusViewModel.shared }
    var shelfViewModel: ShelfStateViewModel { ShelfStateViewModel.shared }
    var shelfSelectionModel: ShelfSelectionModel { ShelfSelectionModel.shared }

    // MARK: - Observers

    var fullscreenMediaDetector: FullscreenMediaDetector { FullscreenMediaDetector.shared }
    var mediaKeyInterceptor: MediaKeyInterceptor { MediaKeyInterceptor.shared }

    // MARK: - Services

    var sharingStateManager: SharingStateManager { SharingStateManager.shared }
    var quickShareService: QuickShareService { QuickShareService.shared }
    var shelfPersistenceService: ShelfPersistenceService { ShelfPersistenceService.shared }
    var thumbnailService: ThumbnailService { ThumbnailService.shared }
    var temporaryFileStorageService: TemporaryFileStorageService { TemporaryFileStorageService.shared }
    var imageProcessingService: ImageProcessingService { ImageProcessingService.shared }
    var lyricsService: LyricsService { LyricsService.shared }
    var imageService: ImageService { ImageService.shared }

    // MARK: - Infrastructure

    var xpcHelperClient: XPCHelperClient { XPCHelperClient.shared }

    private init() {}
}

// MARK: - Protocol for Testability

/// Protocol defining all available dependencies.
/// Implement this with mock instances for unit testing.
@MainActor
protocol DependencyProviding {
    var viewCoordinator: BoringViewCoordinator { get }
    var musicManager: MusicManager { get }
    var batteryViewModel: BatteryStatusViewModel { get }
    var brightnessManager: BrightnessManager { get }
    var volumeManager: VolumeManager { get }
    var webcamManager: WebcamManager { get }
    var shelfViewModel: ShelfStateViewModel { get }
    var sharingStateManager: SharingStateManager { get }
    var notchFaceManager: NotchFaceManager { get }
    var fullscreenMediaDetector: FullscreenMediaDetector { get }
}


