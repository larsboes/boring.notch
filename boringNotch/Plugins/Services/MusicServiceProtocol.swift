import Foundation
import Combine
import AppKit
import SwiftUI

/// Protocol defining the music service capabilities
/// Note: Internal access since PlaybackState is internal
@MainActor
protocol MusicServiceProtocol: Observable {
    var playbackState: PlaybackState { get }
    var currentTrack: TrackInfo? { get }
    var artwork: NSImage? { get }
    var avgColor: NSColor { get }
    var progress: Double { get }
    var volume: Double { get }
    var isShuffled: Bool { get }
    var repeatMode: RepeatMode { get }
    var isFavorite: Bool { get }

    func play() async
    func pause() async
    func togglePlayPause() async
    func next() async
    func previous() async
    func seek(to progress: Double) async
    func setVolume(_ volume: Double) async
    func toggleShuffle() async
    func toggleRepeat() async
    func toggleFavorite() async

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
}

/// Track information for music playback
struct TrackInfo: Equatable, Hashable, Codable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkURL: URL?

    init(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval = 0,
        artworkURL: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }

    /// Convenience initializer for simple cases (backwards compatible)
    init(title: String, artist: String, album: String) {
        self.init(title: title, artist: artist, album: album, duration: 0, artworkURL: nil)
    }
}
