import Foundation

/// Container for all services used by plugins.
/// Provides dependency injection for plugin activation.
///
/// Services are optional until their implementations are created during migration.
/// This allows incremental adoption of the plugin architecture.
@MainActor
final class ServiceContainer {
    // MARK: - Core Services

    /// Music playback service (wraps MusicManager)
    let music: any MusicServiceProtocol

    /// Calendar service (wraps CalendarService)
    public let calendar: any CalendarServiceProtocol

    /// Sound service
    public let sound: any SoundServiceProtocol

    /// Shelf storage service (wraps ShelfService)
    public let shelf: any ShelfServiceProtocol

    /// Weather service (wraps WeatherManager)
    public let weather: any WeatherServiceProtocol

    // MARK: - System Services

    /// Volume control service (wraps VolumeManager)
    public let volume: any VolumeServiceProtocol

    /// Brightness control service (wraps BrightnessManager)
    public let brightness: any BrightnessServiceProtocol

    /// Keyboard backlight control service (wraps KeyboardBacklightManager)
    public let keyboardBacklight: any KeyboardBacklightServiceProtocol

    /// Battery status service (wraps BatteryService)
    public let battery: any BatteryServiceProtocol

    /// Thumbnail generation service
    public let thumbnails: any ThumbnailServiceProtocol

    /// Lyrics fetching service
    public let lyrics: any LyricsServiceProtocol

    /// Sharing state service
    public let sharing: any SharingServiceProtocol

    /// Image processing service
    public let imageProcessing: any ImageProcessingServiceProtocol

    /// Temporary file storage service
    public let temporaryFileStorage: any TemporaryFileStorageServiceProtocol

    /// Webcam service (wraps WebcamManager)
    public let webcam: any WebcamServiceProtocol

    /// Notifications service (wraps NotificationCenterManager)
    public let notifications: any NotificationServiceProtocol

    /// Bluetooth service (wraps BluetoothManager) - optional until implemented
    var bluetooth: (any BluetoothServiceProtocol)?

    /// Face tracking service
    public let face: any FaceServiceProtocol
    
    /// Drag and drop detection service
    public let dragDrop: any DragDropServiceProtocol

    // MARK: - Shelf Helpers

    /// Shelf image processor
    public let shelfImageProcessor: any ShelfImageProcessorProtocol

    /// Shelf file handler
    public let shelfFileHandler: any ShelfFileHandlerProtocol

    // MARK: - Initialization

    /// Default initializer - creates services that are ready
    init() {
        self.music = MusicService(manager: MusicManager())
        self.sound = SoundService()
        self.battery = BatteryService()
        self.calendar = CalendarService()
        self.weather = WeatherService()
        self.face = FaceService()
        self.dragDrop = DragDropService()
        
        self.temporaryFileStorage = TemporaryFileStorageService()
        self.imageProcessing = ImageProcessingService(temporaryFileStorage: self.temporaryFileStorage)
        self.thumbnails = ThumbnailService()
        
        // Initialize Shelf helpers first
        self.shelfImageProcessor = ShelfImageProcessor(imageProcessingService: self.imageProcessing, thumbnailService: self.thumbnails)
        self.shelfFileHandler = ShelfFileHandler(temporaryFileStorage: self.temporaryFileStorage)
        self.shelf = ShelfService(imageProcessor: self.shelfImageProcessor, fileHandler: self.shelfFileHandler)
        
        self.lyrics = LyricsService()
        self.webcam = WebcamManager()
        self.notifications = NotificationCenterManager.shared
        self.volume = VolumeManager()
        self.brightness = BrightnessManager()
        self.keyboardBacklight = KeyboardBacklightManager()
        self.sharing = SharingStateManager.shared
        // Other services will be added as they're migrated
    }

    /// Full initializer for testing or custom configurations
    init(
        music: any MusicServiceProtocol,
        sound: any SoundServiceProtocol,
        calendar: any CalendarServiceProtocol,
        shelf: any ShelfServiceProtocol,
        weather: any WeatherServiceProtocol,
        face: any FaceServiceProtocol,
        dragDrop: any DragDropServiceProtocol,
        webcam: any WebcamServiceProtocol,
        notifications: any NotificationServiceProtocol,
        volume: any VolumeServiceProtocol,
        brightness: any BrightnessServiceProtocol,
        keyboardBacklight: any KeyboardBacklightServiceProtocol,
        battery: any BatteryServiceProtocol,
        thumbnails: any ThumbnailServiceProtocol,
        lyrics: any LyricsServiceProtocol,
        sharing: any SharingServiceProtocol,
        imageProcessing: any ImageProcessingServiceProtocol,
        temporaryFileStorage: any TemporaryFileStorageServiceProtocol,
        shelfImageProcessor: any ShelfImageProcessorProtocol,
        shelfFileHandler: any ShelfFileHandlerProtocol,
        bluetooth: (any BluetoothServiceProtocol)? = nil
    ) {
        self.music = music
        self.sound = sound
        self.calendar = calendar
        self.shelf = shelf
        self.weather = weather
        self.face = face
        self.dragDrop = dragDrop
        self.webcam = webcam
        self.notifications = notifications
        self.volume = volume
        self.brightness = brightness
        self.keyboardBacklight = keyboardBacklight
        self.battery = battery
        self.thumbnails = thumbnails
        self.lyrics = lyrics
        self.sharing = sharing
        self.imageProcessing = imageProcessing
        self.temporaryFileStorage = temporaryFileStorage
        self.shelfImageProcessor = shelfImageProcessor
        self.shelfFileHandler = shelfFileHandler
        self.bluetooth = bluetooth
    }
}
