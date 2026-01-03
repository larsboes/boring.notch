//
//  MusicPlugin.swift
//  boringNotch
//
//  Built-in music player plugin.
//  Wraps MusicService to provide playback controls in the notch.
//
//  Migration notes:
//  - This replaces direct MusicManager.shared access in views
//  - MusicManager becomes MusicService (implements MusicServiceProtocol)
//  - Views receive this plugin via @Environment(PluginManager.self)
//

import SwiftUI
import Combine

// MARK: - Music Plugin

@MainActor
@Observable
final class MusicPlugin: NotchPlugin, PlayablePlugin, PositionedPlugin {

    // MARK: - NotchPlugin

    let id = "com.boringnotch.music"

    let metadata = PluginMetadata(
        name: "Music",
        description: "Control music playback from the notch",
        icon: "music.note",
        version: "1.0.0",
        author: "boringNotch",
        category: .media
    )

    var isEnabled: Bool = true

    private(set) var state: PluginState = .inactive

    // MARK: - PlayablePlugin

    var isPlaying: Bool {
        musicService?.playbackState.isPlaying ?? false
    }

    var nowPlaying: NowPlayingInfo? {
        guard let service = musicService,
              let track = service.currentTrack else {
            return nil
        }
        return NowPlayingInfo(
            track: track,
            artwork: service.artwork,
            progress: service.progress,
            isPlaying: service.playbackState.isPlaying
        )
    }

    var playbackProgress: Double {
        musicService?.progress ?? 0
    }

    // MARK: - PositionedPlugin

    var closedNotchPosition: ClosedNotchPosition { .center }

    // MARK: - Private Properties

    var musicService: (any MusicServiceProtocol)?
    private var settings: PluginSettings?
    private var eventBus: PluginEventBus?
    private var cancellables = Set<AnyCancellable>()

    // Plugin-specific settings
    private var showLyrics: Bool = true
    private var enableSneakPeek: Bool = true
    private var sneakPeekDuration: TimeInterval = 3.0

    // MARK: - Initialization

    init() {}

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        state = .activating

        // Store references
        self.musicService = context.services.music
        self.settings = context.settings
        self.eventBus = context.eventBus

        // Load settings
        loadSettings()

        // Subscribe to playback changes
        setupSubscriptions()

        state = .active
    }

    func deactivate() async {
        cancellables.removeAll()
        musicService = nil
        settings = nil
        eventBus = nil
        state = .inactive
    }

    // MARK: - Playback Controls

    func play() async {
        await musicService?.play()
    }

    func pause() async {
        await musicService?.pause()
    }

    func next() async {
        await musicService?.next()
    }

    func previous() async {
        await musicService?.previous()
    }

    func seek(to progress: Double) async {
        await musicService?.seek(to: progress)
    }

    // MARK: - UI Slots

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive,
              let service = musicService,
              (service.playbackState.isPlaying || !service.isPlayerIdle),
              // Use settings to check if Live Activity is enabled
              (settings?.get("showLiveActivity", default: true) ?? true)
        else {
            return nil
        }
        
        return DisplayRequest(priority: .high, category: DisplayRequest.music)
    }

    func closedNotchContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        guard let service = musicService else { return nil }
        // Only show if playing or we have track info?
        // Original logic was driven by NotchStateMachine.
        // For now, if the state machine asks for this plugin, we return the view.
        
        return AnyView(
            MusicLiveActivity(service: service)
        )
    }

    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }

        // Use the refactored PluginMusicPlayerView which accesses the service internally
        // We pass the namespace via environment or constructor - wait, the namespace comes from the parent view (NotchHomeView)
        // This is a challenge: The expandedPanelContent signature doesn't accept a Namespace.ID.
        // We might need to adjust the protocol or use an EnvironmentObject for the namespace.
        // For now, let's look at how NotchHomeView passes it.
        // It passes `albumArtNamespace: albumArtNamespace` to `MusicPlayerView`.
        
        // TEMPORARY FIX: We can't pass the namespace here because the protocol doesn't support it.
        // We will return a wrapper that expects the namespace to be injected or available.
        // But NotchPlugin protocol returns AnyView, meaning the type is erased.
        //
        // Solution: The plugin system needs a way to pass context like Namespace.
        // For Phase 2, we will use a dedicated EnvironmentKey for the album art namespace.
        
        return AnyView(
            MusicExpandedViewWrapper(plugin: self)
        )
    }

    func settingsContent() -> AnyView? {
        AnyView(
            MusicSettingsView(plugin: self)
        )
    }

    // MARK: - Private Methods

    private func loadSettings() {
        guard let settings = settings else { return }

        showLyrics = settings.get("showLyrics", default: true)
        enableSneakPeek = settings.get("enableSneakPeek", default: true)
        sneakPeekDuration = settings.get("sneakPeekDuration", default: 3.0)
    }

    private func setupSubscriptions() {
        guard let service = musicService else { return }

        // Emit events when playback state changes
        service.playbackStatePublisher
            .sink { [weak self] playbackState in
                guard let self = self else { return }
                let event = MusicPlaybackChangedEvent(
                    isPlaying: playbackState.isPlaying,
                    track: self.musicService?.currentTrack
                )
                self.eventBus?.emit(event)
            }
            .store(in: &cancellables)
            
        // Emit events when sneak peek is requested
        service.sneakPeekPublisher
            .sink { [weak self] request in
                guard let self = self else { return }
                let event = SneakPeekRequestedEvent(
                    sourcePluginId: self.id,
                    request: request
                )
                self.eventBus?.emit(event)
            }
            .store(in: &cancellables)
    }
}

// MARK: - View Wrappers

struct MusicExpandedViewWrapper: View {
    let plugin: MusicPlugin
    @Environment(\.albumArtNamespace) var namespace: Namespace.ID?

    var body: some View {
        PluginMusicPlayerView(plugin: plugin, albumArtNamespace: namespace)
    }
}
