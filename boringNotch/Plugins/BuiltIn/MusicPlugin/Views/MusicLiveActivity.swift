//
//  MusicLiveActivity.swift
//  boringNotch
//
//  Closed notch view for the Music Plugin.
//  Refactored to use Environment values for layout and MusicServiceProtocol for data.
//

import SwiftUI

struct MusicLiveActivity: View {
    let service: any MusicServiceProtocol

    // Environment Dependencies
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    @Environment(\.albumArtNamespace) var albumArtNamespace: Namespace.ID?
    @Environment(\.displayClosedNotchHeight) var displayClosedNotchHeight
    @Environment(\.cornerRadiusScaleFactor) var cornerRadiusScaleFactor
    @Environment(\.cornerRadiusInsets) var cornerRadiusInsets

    var gestureProgress: CGFloat = 0

    private var closedNotchTopRadius: CGFloat {
        let base = cornerRadiusInsets.closed.top
        if let scale = cornerRadiusScaleFactor {
            return max(0, base * scale)
        }
        return max(0, base)
    }

    private var edgeSafeInset: CGFloat {
        max(0, closedNotchTopRadius + 2)
    }

    /// The base notch height (without visualizer extension)
    private var baseNotchHeight: CGFloat {
        let vizEnabled = settings.ambientVisualizerEnabled && service.playbackState.isPlaying
        if vizEnabled {
            // displayClosedNotchHeight includes the visualizer extension
            // Subtract it to get the original notch height
            return displayClosedNotchHeight - settings.ambientVisualizerHeight
        }
        return displayClosedNotchHeight
    }

    private var visualizerEnabled: Bool {
        settings.ambientVisualizerEnabled && service.playbackState.isPlaying
    }

    var body: some View {
        VStack(spacing: 0) {
            musicContent
                .frame(height: baseNotchHeight, alignment: .center)

            if visualizerEnabled {
                AmbientGlowVisualizer(
                    albumColor: Color(nsColor: service.avgColor).ensureMinimumBrightness(factor: 0.5),
                    isPlaying: service.playbackState.isPlaying,
                    height: settings.ambientVisualizerHeight
                )
            }
        }
        .frame(height: displayClosedNotchHeight, alignment: .top)
    }

    @ViewBuilder
    private var musicContent: some View {
        HStack(spacing: 0) {
            let baseArtSize = baseNotchHeight - 12
            let scaledArtSize: CGFloat = {
                if let scale = cornerRadiusScaleFactor {
                    return baseNotchHeight - 12 * scale
                }
                return baseArtSize
            }()

            let closedCornerRadius: CGFloat = {
                let base = MusicPlayerImageSizes.cornerRadiusInset.closed
                if let scale = cornerRadiusScaleFactor {
                    return max(0, base * scale)
                }
                return base
            }()

            GeometryReader { geo in
                if let artwork = service.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: closedCornerRadius))
                        .clipped()
                        .ifLet(vm.phase.isTransitioning ? nil : albumArtNamespace) { view, ns in
                            view.matchedGeometryEffect(id: "albumArt", in: ns)
                        }
                }
            }
            .frame(width: scaledArtSize, height: scaledArtSize)
            .padding(.leading, 10)

            Rectangle()
                .fill(Color.clear)
                .frame(width: max(0, vm.closedNotchSize.width - self.edgeSafeInset * 2))

            HStack {
                AudioSpectrumView(
                    isPlaying: service.playbackState.isPlaying,
                    tintColor: settings.coloredSpectrogram
                        ? Color(nsColor: service.avgColor).ensureMinimumBrightness(factor: 0.5)
                        : Color.gray
                )
                .frame(width: 16, height: 12)
            }
            .frame(
                width: max(0, baseNotchHeight - 12 + gestureProgress / 2),
                height: max(0, baseNotchHeight - 12),
                alignment: .center
            )
            .padding(.trailing, 10)
        }
        .padding(.horizontal, self.edgeSafeInset)
    }
}
