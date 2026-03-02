//
//  PluginMusicPlayerView.swift
//  boringNotch
//
//  Refactored Music Player View for the Plugin Architecture.
//  Uses MusicServiceProtocol instead of MusicManager singleton.
//

import SwiftUI
import Combine
import Defaults

struct PluginMusicPlayerView: View {
    let plugin: MusicPlugin
    let albumArtNamespace: Namespace.ID?
    @Environment(BoringViewModel.self) var vm

    var body: some View {
        if let service = plugin.musicService {
            HStack(spacing: 14) {
                PluginAlbumArtView(service: service, albumArtNamespace: albumArtNamespace)
                    .frame(width: 120, height: 120)
                    .padding(.leading, 10)
                
                PluginMusicControlsView(service: service, plugin: plugin)
                    .drawingGroup()
                    .compositingGroup()
            }
            .padding(.vertical, 8)
        } else {
            Text("Music Service Unavailable")
                .foregroundStyle(.secondary)
        }
    }
}

struct PluginAlbumArtView: View {
    let service: any MusicServiceProtocol
    let albumArtNamespace: Namespace.ID?
    
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if settings.lightingEffect {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        // Fallback to empty image if nil, though service should provide default
        Image(nsImage: service.artwork ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened)
            )
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 35)
            .opacity(service.playbackState.isPlaying ? 0.45 : 0)
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                Task { await service.openMusicApp() }
            } label: {
                albumArtImage
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(service.playbackState.isPlaying ? 1 : 0.9)
            .animation(.easeOut(duration: 0.2), value: service.playbackState.isPlaying)
            
            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened)
            .foregroundColor(Color.black)
            .opacity(service.playbackState.isPlaying ? 0 : 0.6)
            .animation(.easeOut(duration: 0.25), value: service.playbackState.isPlaying)
    }

    private var albumArtImage: some View {
        GeometryReader { geo in
            Image(nsImage: service.artwork ?? NSImage())
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.width)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened
                    )
                )
                .clipped()
                .ifLet(albumArtNamespace) { view, ns in
                    view.matchedGeometryEffect(id: "albumArt", in: ns)
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PluginMusicControlsView: View {
    let service: any MusicServiceProtocol
    let plugin: MusicPlugin
    
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            songInfo
            musicSliderWithTimes
            playbackControls
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 8)
    }

    private var songInfo: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 2) {
                if let track = service.currentTrack {
                    MarqueeText(
                        track.title,
                        font: .headline,
                        color: .white,
                        frameWidth: geo.size.width
                    )
                    .fontWeight(.semibold)
                    
                    MarqueeText(
                        track.artist,
                        font: .subheadline,
                        color: settings.playerColorTinting
                            ? Color(nsColor: service.avgColor)
                                .ensureMinimumBrightness(factor: 0.6) : .gray,
                        frameWidth: geo.size.width
                    )
                }
                
                if settings.enableLyrics {
                    lyricsView(width: geo.size.width)
                }
            }
        }
        .frame(height: settings.enableLyrics ? 58 : 42)
    }
    
    @ViewBuilder
    private func lyricsView(width: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let currentElapsed: Double = {
                guard service.playbackState.isPlaying else { return service.elapsedTime }
                let delta = timeline.date.timeIntervalSince(service.timestampDate)
                let progressed = service.elapsedTime + (delta * service.playbackRate)
                return min(max(progressed, 0), service.songDuration)
            }()
            
            let line: String = {
                if service.isFetchingLyrics { return "Loading lyrics…" }
                if !service.syncedLyrics.isEmpty {
                    // Simple linear search for now, could be binary search
                    // Find the last lyric line where time <= currentElapsed
                    if let match = service.syncedLyrics.last(where: { $0.time <= currentElapsed }) {
                        return match.text
                    }
                }
                let trimmed = service.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
            }()
            
            let isPersian = line.unicodeScalars.contains { scalar in
                let v = scalar.value
                return v >= 0x0600 && v <= 0x06FF
            }
            
            MarqueeText(
                line,
                font: .subheadline,
                color: service.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                frameWidth: width
            )
            .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
            .lineLimit(1)
            .opacity(service.playbackState.isPlaying ? 1 : 0)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var musicSliderWithTimes: some View {
        TimelineView(.animation(minimumInterval: service.playbackRate > 0 ? 0.1 : nil)) { timeline in
            HStack(spacing: 8) {
                Text(timeString(from: sliderValue))
                    .font(.caption2)
                    .foregroundColor(
                        settings.playerColorTinting
                        ? Color(nsColor: service.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray
                    )
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                
                CustomSlider(
                    value: $sliderValue,
                    range: 0...service.songDuration,
                    color: settings.sliderColor == SliderColorEnum.albumArt
                        ? Color(nsColor: service.avgColor).ensureMinimumBrightness(factor: 0.8)
                        : settings.sliderColor == SliderColorEnum.accent ? .effectiveAccent : .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { newValue in
                        Task { await service.seek(to: newValue) }
                    }
                )
                .frame(height: 8)
                
                Text(timeString(from: service.songDuration))
                    .font(.caption2)
                    .foregroundColor(
                        settings.playerColorTinting
                        ? Color(nsColor: service.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray
                    )
                    .monospacedDigit()
                    .frame(width: 36, alignment: .leading)
            }
            .onChange(of: timeline.date) {
                guard !dragging, service.timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
                sliderValue = service.estimatedPlaybackPosition(at: timeline.date)
            }
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 6) {
            // App icon
            AppIcon(for: service.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .onTapGesture {
                    Task { await service.openMusicApp() }
                }
            
            Spacer()
            
            // Core playback controls
            HStack(spacing: 8) {
                HoverButton(icon: "backward.fill", scale: .medium) {
                    Task { await service.previous() }
                }
                
                HoverButton(icon: service.playbackState.isPlaying ? "pause.fill" : "play.fill", scale: .large) {
                    Task { await service.togglePlayPause() }
                }
                
                HoverButton(icon: "forward.fill", scale: .medium) {
                    Task { await service.next() }
                }
            }
            
            Spacer()
            
            // Extra controls
            // Logic for hiding can be re-enabled later via layout context
            extraControlsView
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var extraControlsView: some View {
        Menu {
            Button(action: { Task { await service.toggleShuffle() } }) {
                Label(service.isShuffled ? "Shuffle On" : "Shuffle Off", 
                      systemImage: "shuffle")
            }
            Button(action: { Task { await service.toggleRepeat() } }) {
                Label(repeatLabel, systemImage: repeatIcon)
            }
            if service.canFavoriteTrack {
                Button(action: { Task { await service.toggleFavorite() } }) {
                    Label(service.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: service.isFavorite ? "heart.fill" : "heart")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
    
    private var repeatLabel: String {
        switch service.repeatMode {
        case .off: return "Repeat Off"
        case .all: return "Repeat All"
        case .one: return "Repeat One"
        }
    }

    private var repeatIcon: String {
        switch service.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}
