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

    private var musicService: (any MusicServiceProtocol)?
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

    func closedNotchContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }
        guard let nowPlaying = nowPlaying else { return nil }

        return AnyView(
            MusicClosedNotchView(
                nowPlaying: nowPlaying,
                onTap: { [weak self] in
                    Task { await self?.togglePlayPause() }
                }
            )
        )
    }

    func expandedPanelContent() -> AnyView? {
        guard isEnabled, state.isActive else { return nil }

        return AnyView(
            MusicExpandedView(plugin: self)
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
    }
}

// MARK: - Closed Notch View

struct MusicClosedNotchView: View {
    let nowPlaying: NowPlayingInfo
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Album artwork
            if let artwork = nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Track info
            VStack(alignment: .leading, spacing: 0) {
                Text(nowPlaying.track.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(nowPlaying.track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Play/pause indicator
            Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Expanded View

struct MusicExpandedView: View {
    let plugin: MusicPlugin

    var body: some View {
        VStack(spacing: 16) {
            if let nowPlaying = plugin.nowPlaying {
                // Album artwork (large)
                if let artwork = nowPlaying.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                }

                // Track info
                VStack(spacing: 4) {
                    Text(nowPlaying.track.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(nowPlaying.track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Progress bar
                ProgressView(value: nowPlaying.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)

                // Playback controls
                HStack(spacing: 32) {
                    Button {
                        Task { await plugin.previous() }
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await plugin.togglePlayPause() }
                    } label: {
                        Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await plugin.next() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No music playing
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No music playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Settings View

struct MusicSettingsView: View {
    let plugin: MusicPlugin

    @State private var showLyrics = true
    @State private var enableSneakPeek = true
    @State private var sneakPeekDuration = 3.0

    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show lyrics", isOn: $showLyrics)
            }

            Section("Sneak Peek") {
                Toggle("Enable sneak peek", isOn: $enableSneakPeek)

                if enableSneakPeek {
                    Slider(value: $sneakPeekDuration, in: 1...10, step: 0.5) {
                        Text("Duration: \(sneakPeekDuration, specifier: "%.1f")s")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Music Expanded") {
    MusicExpandedView(plugin: MusicPlugin())
        .frame(width: 300, height: 400)
}
#endif
