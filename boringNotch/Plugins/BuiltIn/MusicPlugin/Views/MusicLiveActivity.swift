//
//  MusicLiveActivity.swift
//  boringNotch
//
//  Closed notch view for the Music Plugin.
//  Refactored to use Environment values for layout and MusicServiceProtocol for data.
//

import SwiftUI
import Defaults

struct MusicLiveActivity: View {
    let service: any MusicServiceProtocol
    
    // Environment Dependencies
    @Environment(BoringViewModel.self) var vm
    @Environment(\.albumArtNamespace) var albumArtNamespace: Namespace.ID?
    @Environment(\.displayClosedNotchHeight) var displayClosedNotchHeight
    @Environment(\.cornerRadiusScaleFactor) var cornerRadiusScaleFactor
    @Environment(\.cornerRadiusInsets) var cornerRadiusInsets
    
    // Constants (could be passed via layout context if dynamic)
    // For now we assume gestureProgress is handled by the parent container or not needed for the static view
    // In the original, gestureProgress affected the width of the spectrum container
    var gestureProgress: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            // Closed-mode album art: scale padding and corner radius according to cornerRadiusScaleFactor
            let baseArtSize = displayClosedNotchHeight - 12
            let scaledArtSize: CGFloat = {
                if let scale = cornerRadiusScaleFactor {
                    return displayClosedNotchHeight - 12 * scale
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
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: closedCornerRadius
                            )
                        )
                        .clipped()
                        .ifLet(albumArtNamespace) { view, ns in
                            view.matchedGeometryEffect(id: "albumArt", in: ns)
                        }
                }
            }
            .frame(
                width: scaledArtSize,
                height: scaledArtSize
            )

            // Fixed-width middle section matching physical notch width
            Rectangle()
                .fill(Color.clear)
                .frame(width: vm.closedNotchSize.width)

            HStack {
                AudioSpectrumView(
                    isPlaying: service.playbackState.isPlaying,
                    tintColor: Defaults[.coloredSpectrogram]
                    ? Color(nsColor: service.avgColor).ensureMinimumBrightness(factor: 0.5)
                    : Color.gray
                )
                .frame(width: 16, height: 12)
            }
            .frame(
                width: max(
                    0,
                    displayClosedNotchHeight - 12
                        + gestureProgress / 2
                ),
                height: max(
                    0,
                    displayClosedNotchHeight - 12
                ),
                alignment: .center
            )
            .padding(.trailing, 10)
        }
        .frame(
            height: displayClosedNotchHeight,
            alignment: .center
        )
    }
}
