//
//  Constants.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 10. 17..
//  Modified by Arsh Anwar
//

import SwiftUI
import Defaults

// MARK: - File System Paths
private let availableDirectories = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let bundleIdentifier = Bundle.main.bundleIdentifier!
let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

let temporaryDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
let spacing: CGFloat = 16

struct BluetoothDeviceIconMapping: Codable, Defaults.Serializable {
    let UUID: UUID
    let deviceName: String
    var sfSymbolName: String

    init(UUID: Foundation.UUID = Foundation.UUID(), deviceName: String, sfSymbolName: String) {
        self.UUID = UUID
        self.deviceName = deviceName
        self.sfSymbolName = sfSymbolName
    }
}

enum CalendarSelectionState: Codable, Defaults.Serializable, Sendable {
    case all
    case selected(Set<String>)
}

enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

// Define notification names at file scope
extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
    static let accessibilityAuthorizationChanged = Notification.Name("accessibilityAuthorizationChanged")
    static let sharingDidFinish = Notification.Name("com.boringNotch.sharingDidFinish")
    static let accentColorChanged = Notification.Name("AccentColorChanged")
}

enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    var id: String { self.rawValue }
}

enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case standard = "Default"
    case inline = "Inline"
    case minimal = "Minimal"
    case expanding = "Expanding"
    var id: String { self.rawValue }
    static let selectableCases: [SneakPeekStyle] = [.standard, .inline, .minimal]
}

enum OptionKeyAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case openSettings = "Open System Settings"
    case showHUD = "Show HUD"
    case none = "No Action"
    var id: String { self.rawValue }
}

enum Mood: String, Codable, CaseIterable, Defaults.Serializable {
    case happy, neutral, sad, surprised, angry, sleepy
}

enum LiquidGlassStyle: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case `default` = "Default"
    case subtle = "Subtle"
    case vibrant = "Vibrant"
    var id: String { rawValue }
    var configuration: LiquidGlassConfiguration {
        switch self {
        case .default: return .default
        case .subtle: return .subtle
        case .vibrant: return .vibrant
        }
    }
}

enum NotificationDeliveryStyle: String, CaseIterable, Defaults.Serializable {
    case banner
    case soundOnly
    var localizedName: String {
        switch self {
        case .banner: return "Banner & Sound"
        case .soundOnly: return "Sound Only"
        }
    }
}

enum AmbientVisualizerMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case simulated = "simulated"
    case realAudio = "realAudio"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulated: return "Generative"
        case .realAudio: return "Audio Reactive"
        }
    }

    var icon: String {
        switch self {
        case .simulated: return "wand.and.stars"
        case .realAudio: return "waveform.path.ecg"
        }
    }
}
