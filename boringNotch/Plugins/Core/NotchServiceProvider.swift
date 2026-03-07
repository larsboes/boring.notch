//
//  NotchServiceProvider.swift
//  boringNotch
//

import Foundation
import CoreBluetooth
import Observation

/// Protocol providing access to all services available to plugins.
/// Extracted from ServiceContainer to allow better dependency injection and testing.
@MainActor
protocol NotchServiceProvider {
    var music: any MusicServiceProtocol { get }
    var calendar: any CalendarServiceProtocol { get }
    var sound: any SoundServiceProtocol { get }
    var shelf: any ShelfServiceProtocol { get }
    var weather: any WeatherServiceProtocol { get }
    var volume: any VolumeServiceProtocol { get }
    var brightness: any BrightnessServiceProtocol { get }
    var keyboardBacklight: any KeyboardBacklightServiceProtocol { get }
    var battery: any BatteryServiceProtocol { get }
    var thumbnails: any ThumbnailServiceProtocol { get }
    var lyrics: any LyricsServiceProtocol { get }
    var sharing: any SharingServiceProtocol { get }
    var imageProcessing: any ImageProcessingServiceProtocol { get }
    var temporaryFileStorage: any TemporaryFileStorageServiceProtocol { get }
    var webcam: any WebcamServiceProtocol { get }
    var bluetooth: (any BluetoothServiceProtocol)? { get }
    var face: any FaceServiceProtocol { get }
    var dragDrop: any DragDropServiceProtocol { get }
    var shelfImageProcessor: any ShelfImageProcessorProtocol { get }
    var shelfFileHandler: any ShelfFileHandlerProtocol { get }
    var quickLook: any QuickLookServiceProtocol { get }
    var quickShare: QuickShareService { get }
    var notifications: any NotificationServiceProtocol { get }
    
    /// API Route Registrar (optional, only available when API server is running)
    var apiRouteRegistrar: (any APIRouteRegistrar)? { get }
    
    /// AI text generation service (domain-level — use this, not AIManager directly)
    var ai: any AITextGenerationService { get }
    
    // App-specific services still used by legacy views/plugins
    var bluetoothManager: any BluetoothStateServiceProtocol { get }
    var notesManager: any NotesServiceProtocol { get }
    var clipboardManager: any ClipboardServiceProtocol { get }

    /// XPC Helper for privileged operations (accessibility, brightness control)
    var xpcHelper: any XPCHelperServiceProtocol { get }
}

@MainActor
protocol NotesServiceProtocol: AnyObject, Observable {
    var notes: [NoteItem] { get }
    func addNote(title: String, content: String)
    func deleteNote(_ note: NoteItem)
}

@MainActor
protocol ClipboardServiceProtocol: AnyObject, Observable {
    var items: [ClipboardItem] { get }
    func startMonitoring()
    func stopMonitoring()
    func clearHistory()
    func copyToPasteboard(_ item: ClipboardItem)
    func deleteItem(_ item: ClipboardItem)
}

@MainActor
protocol BluetoothStateServiceProtocol: AnyObject, Observable {
    var connectedDevices: [BluetoothDevice] { get }
    var bluetoothState: CBManagerState { get }
    var isInitialized: Bool { get }
    func initializeBluetooth()
}

extension NotesManager: NotesServiceProtocol {}
extension ClipboardManager: ClipboardServiceProtocol {}
extension BluetoothManager: BluetoothStateServiceProtocol {}
