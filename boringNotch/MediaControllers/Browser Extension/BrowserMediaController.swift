//
//  BrowserMediaController.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-16.
//

import Combine
import Foundation
import SwiftUI

@Observable
@MainActor
final class BrowserMediaController: MediaControllerProtocol {
    private var cancellables = Set<AnyCancellable>()

    var playbackState = PlaybackState(bundleIdentifier: "com.google.Chrome") {
        didSet { _playbackStateSubject.send(playbackState) }
    }

    @ObservationIgnored
    private let _playbackStateSubject = CurrentValueSubject<PlaybackState, Never>(
        PlaybackState(bundleIdentifier: "com.google.Chrome")
    )
    
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        _playbackStateSubject.eraseToAnyPublisher()
    }

    var supportsVolumeControl: Bool { false }
    var supportsFavorite: Bool { false }

    init() {
        BrowserExtensionServer.shared.start()
        
        BrowserExtensionServer.shared.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] browserState in
                self?.handleStateUpdate(browserState)
            }
            .store(in: &cancellables)
    }

    private func handleStateUpdate(_ browserState: BrowserMediaState) {
        var newState = playbackState
        
        newState.title = browserState.title
        newState.artist = browserState.artist
        newState.album = browserState.album
        newState.isPlaying = !browserState.isPaused
        newState.currentTime = browserState.currentTime
        newState.duration = browserState.duration
        newState.playbackRate = browserState.playbackRate
        newState.bundleIdentifier = browserState.bundleIdentifier
        newState.lastUpdated = Date()
        
        playbackState = newState
    }

    func play() async { BrowserExtensionServer.shared.sendCommand(BrowserMediaCommand(command: "play")) }
    func pause() async { BrowserExtensionServer.shared.sendCommand(BrowserMediaCommand(command: "pause")) }
    func togglePlay() async { BrowserExtensionServer.shared.sendCommand(BrowserMediaCommand(command: playbackState.isPlaying ? "pause" : "play")) }
    func nextTrack() async { BrowserExtensionServer.shared.sendCommand(BrowserMediaCommand(command: "next")) }
    func previousTrack() async { BrowserExtensionServer.shared.sendCommand(BrowserMediaCommand(command: "previous")) }
    func seek(to time: Double) async { BrowserExtensionServer.shared.sendCommand(BrowserMediaCommand(command: "seek", value: time)) }

    func setVolume(_ level: Double) async { }
    func toggleShuffle() async { }
    func toggleRepeat() async { }
    func setFavorite(_ favorite: Bool) async { }
    
    func isActive() -> Bool {
        // We consider it active if we have received a state update recently
        return Date().timeIntervalSince(playbackState.lastUpdated) < 10.0
    }
    
    func updatePlaybackInfo() async {
        // Handled via WebSocket push from the extension
    }
}
