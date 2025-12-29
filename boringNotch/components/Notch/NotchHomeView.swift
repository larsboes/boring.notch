//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan & Arsh Anwar
//

import Combine
import Defaults
import SwiftUI

// MARK: - Music Player Components

struct MusicPlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        HStack(spacing: 14) {
            AlbumArtView(vm: vm, albumArtNamespace: albumArtNamespace)
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
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if Defaults[.lightingEffect] {
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
    @ObservedObject var musicManager = MusicManager.shared
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
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
                    color: Defaults[.playerColorTinting]
                        ? Color(nsColor: musicManager.avgColor)
                            .ensureMinimumBrightness(factor: 0.6) : .gray,
                    frameWidth: geo.size.width
                )
                if Defaults[.enableLyrics] {
                    lyricsView(width: geo.size.width)
                }
            }
        }
        .frame(height: Defaults[.enableLyrics] ? 58 : 42)
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
                        Defaults[.playerColorTinting]
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray
                    )
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                
                CustomSlider(
                    value: $sliderValue,
                    range: 0...musicManager.songDuration,
                    color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                        ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.8)
                        : Defaults[.sliderColor] == SliderColorEnum.accent ? .effectiveAccent : .white,
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
                        Defaults[.playerColorTinting]
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
        !(Defaults[.showCalendar] && Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded)
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
    @ObservedObject var musicManager = MusicManager.shared

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

struct VolumeControlView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @State private var volumeSliderValue: Double = 0.5
    @State private var dragging: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var lastVolumeUpdateTime: Date = Date.distantPast
    private let volumeUpdateThrottle: TimeInterval = 0.1
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if musicManager.volumeControlSupported {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        showVolumeSlider.toggle()
                    }
                }
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(musicManager.volumeControlSupported ? .white : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!musicManager.volumeControlSupported)
            .frame(width: 24)

            if showVolumeSlider && musicManager.volumeControlSupported {
                CustomSlider(
                    value: $volumeSliderValue,
                    range: 0.0...1.0,
                    color: .white,
                    dragging: $dragging,
                    lastDragged: .constant(Date.distantPast),
                    onValueChange: { newValue in
                        MusicManager.shared.setVolume(to: newValue)
                    },
                    onDragChange: { newValue in
                        let now = Date()
                        if now.timeIntervalSince(lastVolumeUpdateTime) > volumeUpdateThrottle {
                            MusicManager.shared.setVolume(to: newValue)
                            lastVolumeUpdateTime = now
                        }
                    }
                )
                .frame(width: 48, height: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .clipped()
        .onReceive(musicManager.$volume) { volume in
            if !dragging {
                volumeSliderValue = volume
            }
        }
        .onReceive(musicManager.$volumeControlSupported) { supported in
            if !supported {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showVolumeSlider = false
                }
            }
        }
        .onChange(of: showVolumeSlider) { _, isShowing in
            if isShowing {
                // Sync volume from app when slider appears
                Task {
                    await MusicManager.shared.syncVolumeFromActiveApp()
                }
            }
        }
        .onDisappear {
            // volumeUpdateTask?.cancel() // No longer needed
        }
    }
    
    
    private var volumeIcon: String {
        if !musicManager.volumeControlSupported {
            return "speaker.slash"
        } else if volumeSliderValue == 0 {
            return "speaker.slash.fill"
        } else if volumeSliderValue < 0.33 {
            return "speaker.1.fill"
        } else if volumeSliderValue < 0.66 {
            return "speaker.2.fill"
        } else {
            return "speaker.3.fill"
        }
    }
}

// MARK: - Main View

struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    let albumArtNamespace: Namespace.ID

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)
            .transition(.opacity)
    }

    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
    }
    
    private var shouldShowCalendar: Bool {
        Defaults[.showCalendar]
    }
    
    private var shouldShowWeather: Bool {
        Defaults[.showWeather]
    }
    
    private var additionalItemsCount: Int {
        var count = 0
        if shouldShowCalendar { count += 1 }
        if shouldShowWeather { count += 1 }
        if shouldShowCamera { count += 1 }
        return count
    }
    
    private var itemWidth: CGFloat {
        // Music player takes ~100px, we need to keep total under 640 for notch curve
        // When camera is shown, it needs more space
        if shouldShowCamera {
            switch additionalItemsCount {
            case 2: return 170  // calendar/weather + camera
            case 3: return 130  // This shouldn't happen often
            default: return 215
            }
        } else {
            switch additionalItemsCount {
            case 1: return 215  // Just calendar or weather
            case 2: return 180  // Calendar + weather
            default: return 215
            }
        }
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: additionalItemsCount >= 2 ? 10 : 15) {
            MusicPlayerView(albumArtNamespace: albumArtNamespace)
                .blur(radius: vm.notchState == .closed ? 30 : 0)

            if shouldShowCalendar {
                CalendarView()
                    .frame(width: itemWidth)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)
                    .transition(.opacity)
                    .blur(radius: vm.notchState == .closed ? 30 : 0)
            }
            
            if shouldShowWeather {
                WeatherView()
                    .frame(width: itemWidth)
                    .environmentObject(vm)
                    .transition(.opacity)
                    .blur(radius: vm.notchState == .closed ? 30 : 0)
            }

            if shouldShowCamera {
                CameraPreviewView(webcamManager: webcamManager)
                    .scaledToFit()
                    .opacity(vm.notchState == .closed ? 0 : 1)
                    // Do not blur the camera view to prevent "Unable to render flattened version" errors
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.76, blendDuration: 0), value: shouldShowCamera)
            }
        }
        .padding(.horizontal, 4)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }
}

struct MusicSliderView: View {
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    var onValueChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 4) {
            CustomSlider(
                value: $sliderValue,
                range: 0...duration,
                color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.8)
                    : Defaults[.sliderColor] == SliderColorEnum.accent ? .effectiveAccent : .white,
                dragging: $dragging,
                lastDragged: $lastDragged,
                onValueChange: onValueChange
            )
            .frame(height: 8, alignment: .center)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(timeString(from: duration))
            }
            .foregroundColor(
                Defaults[.playerColorTinting]
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.6) : .gray
            )
            .font(.caption2)
        }
        .onChange(of: currentDate) {
            guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
    }

    func timeString(from seconds: Double) -> String {
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

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 6 : 4)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.25))
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragging = false
                        }
                        lastDragged = Date()
                    }
            )
            .animation(.easeOut(duration: 0.15), value: dragging)
        }
    }
}
