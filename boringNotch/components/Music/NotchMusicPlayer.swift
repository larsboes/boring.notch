//
//  NotchMusicPlayer.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import Combine
import Defaults
import SwiftUI

struct MusicPlayerView: View {
    @Environment(BoringViewModel.self) var vm
    let albumArtNamespace: Namespace.ID

    var body: some View {
        HStack(spacing: 14) {
            AlbumArtView(albumArtNamespace: albumArtNamespace)
                .frame(width: 120, height: 120)
                .padding(.leading, 10)
            MusicControlsView()
                .drawingGroup()
                .compositingGroup()
        }
        .padding(.vertical, 8)
    }
}

struct AlbumArtView: View {
    var musicManager = MusicManager.shared
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    let albumArtNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if settings.lightingEffect {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened)
            )
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 35)
            .opacity(musicManager.isPlaying ? 0.45 : 0)
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                albumArtImage
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(musicManager.isPlaying ? 1 : 0.9)
            .animation(.easeOut(duration: 0.2), value: musicManager.isPlaying)
            
            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened)
            .foregroundColor(Color.black)
            .opacity(musicManager.isPlaying ? 0 : 0.6)
            .animation(.easeOut(duration: 0.25), value: musicManager.isPlaying)
    }

    private var albumArtImage: some View {
        GeometryReader { geo in
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.width)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened
                    )
                )
                .clipped()
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct MusicControlsView: View {
    var musicManager = MusicManager.shared
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    @Bindable var webcamManager = WebcamManager.shared
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    @Default(.musicControlSlots) private var slotConfig
    @Default(.musicControlSlotLimit) private var slotLimit

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
                MarqueeText(
                    musicManager.songTitle,
                    font: .headline,
                    color: .white,
                    frameWidth: geo.size.width
                )
                .fontWeight(.semibold)
                MarqueeText(
                    musicManager.artistName,
                    font: .subheadline,
                    color: settings.playerColorTinting
                        ? Color(nsColor: musicManager.avgColor)
                            .ensureMinimumBrightness(factor: 0.6) : .gray,
                    frameWidth: geo.size.width
                )
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
                guard musicManager.isPlaying else { return musicManager.elapsedTime }
                let delta = timeline.date.timeIntervalSince(musicManager.timestampDate)
                let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
                return min(max(progressed, 0), musicManager.songDuration)
            }()
            let line: String = {
                if LyricsService.shared.isFetchingLyrics { return "Loading lyrics…" }
                if !LyricsService.shared.syncedLyrics.isEmpty {
                    return LyricsService.shared.lyricLine(at: currentElapsed)
                }
                let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
            }()
            let isPersian = line.unicodeScalars.contains { scalar in
                let v = scalar.value
                return v >= 0x0600 && v <= 0x06FF
            }
            MarqueeText(
                line,
                font: .subheadline,
                color: musicManager.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                frameWidth: width
            )
            .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
            .lineLimit(1)
            .opacity(musicManager.isPlaying ? 1 : 0)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var musicSliderWithTimes: some View {
        TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            HStack(spacing: 8) {
                Text(timeString(from: sliderValue))
                    .font(.caption2)
                    .foregroundColor(
                        settings.playerColorTinting
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray
                    )
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                
                CustomSlider(
                    value: $sliderValue,
                    range: 0...musicManager.songDuration,
                    color: settings.sliderColor == SliderColorEnum.albumArt
                        ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.8)
                        : settings.sliderColor == SliderColorEnum.accent ? .effectiveAccent : .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { newValue in
                        MusicManager.shared.seek(to: newValue)
                    }
                )
                .frame(height: 8)
                
                Text(timeString(from: musicManager.songDuration))
                    .font(.caption2)
                    .foregroundColor(
                        settings.playerColorTinting
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray
                    )
                    .monospacedDigit()
                    .frame(width: 36, alignment: .leading)
            }
            .onChange(of: timeline.date) {
                guard !dragging, musicManager.timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
                sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: timeline.date)
            }
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 6) {
            // App icon
            AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .onTapGesture {
                    musicManager.openMusicApp()
                }
            
            Spacer()
            
            // Core playback controls
            HStack(spacing: 8) {
                HoverButton(icon: "backward.fill", scale: .medium) {
                    MusicManager.shared.previousTrack()
                }
                
                HoverButton(icon: musicManager.isPlaying ? "pause.fill" : "play.fill", scale: .large) {
                    MusicManager.shared.togglePlay()
                }
                
                HoverButton(icon: "forward.fill", scale: .medium) {
                    MusicManager.shared.nextTrack()
                }
            }
            
            Spacer()
            
            // Optional additional controls (smaller)
            if shouldShowExtraControls {
                extraControlsView
            } else {
                Color.clear.frame(width: 22, height: 22)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var shouldShowExtraControls: Bool {
        // Only show extra controls if space permits (no camera/calendar taking space)
        !(settings.showCalendar && settings.showMirror && webcamManager.cameraAvailable && vm.isCameraExpanded)
    }
    
    @ViewBuilder
    private var extraControlsView: some View {
        Menu {
            Button(action: { MusicManager.shared.toggleShuffle() }) {
                Label(musicManager.isShuffled ? "Shuffle On" : "Shuffle Off", 
                      systemImage: "shuffle")
            }
            Button(action: { MusicManager.shared.toggleRepeat() }) {
                Label(repeatLabel, systemImage: repeatIcon)
            }
            if musicManager.canFavoriteTrack {
                Button(action: { MusicManager.shared.toggleFavoriteTrack() }) {
                    Label(musicManager.isFavoriteTrack ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: musicManager.isFavoriteTrack ? "heart.fill" : "heart")
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
        switch musicManager.repeatMode {
        case .off: return "Repeat Off"
        case .all: return "Repeat All"
        case .one: return "Repeat One"
        }
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
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

struct FavoriteControlButton: View {
    var musicManager = MusicManager.shared

    var body: some View {
        HoverButton(icon: iconName, iconColor: iconColor, scale: .medium) {
            MusicManager.shared.toggleFavoriteTrack()
        }
        .disabled(!musicManager.canFavoriteTrack)
        .opacity(musicManager.canFavoriteTrack ? 1 : 0.35)
    }

    private var iconName: String {
        musicManager.isFavoriteTrack ? "heart.fill" : "heart"
    }

    private var iconColor: Color {
        musicManager.isFavoriteTrack ? .red : .primary
    }
}

private extension Array where Element == MusicControlButton {
    func padded(to length: Int, filler: MusicControlButton) -> [MusicControlButton] {
        if count >= length { return self }
        return self + Array(repeating: filler, count: length - count)
    }
}

// MARK: - Volume Control View

