//
//  NotchContentRouter.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Routes notch content based on NotchStateMachine state.
//  This will eventually replace the 120-line if-else chains in ContentView.
//

import SwiftUI
import Defaults

/// Routes notch content based on the current display state.
/// Uses NotchStateMachine to determine what content to show.
struct NotchContentRouter: View {
    let displayState: NotchDisplayState
    let albumArtNamespace: Namespace.ID

    // Required environment and state for rendering
    @Environment(BoringViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager
    @Bindable var coordinator: BoringViewCoordinator
    // var musicManager: MusicManager // Removed in favor of pluginManager
    var batteryModel: BatteryStatusViewModel

    /// Height to use for closed notch content
    var closedNotchHeight: CGFloat
    
    var cornerRadiusScaleFactor: CGFloat?
    var cornerRadiusInsets: CornerRadiusInsets

    var body: some View {
        switch displayState {
        case .helloAnimation:
            helloAnimationContent

        case .closed(let content):
            closedContent(content)

        case .open(let view):
            openContent(view)

        case .sneakPeek(let type, let value, let icon):
            sneakPeekContent(type: type, value: value, icon: icon)

        case .expanding(let type):
            expandingContent(type: type)
        }
    }

    // MARK: - Hello Animation

    @ViewBuilder
    private var helloAnimationContent: some View {
        Spacer()
        HelloAnimation(onFinish: {
            vm.closeHello()
        })
        .frame(width: getClosedNotchSize().width, height: 80)
        .padding(.top, 40)
        Spacer()
    }

    // MARK: - Closed Content

    @ViewBuilder
    private func closedContent(_ content: NotchDisplayState.ClosedContent) -> some View {
        switch content {
        case .idle:
            idleContent

        case .musicLiveActivity:
            if let musicService = pluginManager?.services.music {
                MusicLiveActivity(
                    musicService: musicService,
                    albumArtNamespace: albumArtNamespace,
                    displayClosedNotchHeight: closedNotchHeight,
                    cornerRadiusScaleFactor: cornerRadiusScaleFactor,
                    cornerRadiusInsets: cornerRadiusInsets
                )
            }

        case .batteryNotification:
            batteryNotificationContent

        case .face:
            BoringFaceAnimation(height: closedNotchHeight)

        case .inlineHUD(let type, let value, let icon):
            inlineHUDContent(type: type, value: value, icon: icon)

        case .sneakPeek(let type, let value, let icon):
            sneakPeekOverlayContent(type: type, value: value, icon: icon)
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: vm.closedNotchSize.width, height: closedNotchHeight)
    }

    @ViewBuilder
    private var batteryNotificationContent: some View {
        HStack(spacing: 0) {
            HStack {
                Text(batteryModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
            }

            Rectangle()
                .fill(Color.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                BoringBatteryView(
                    batteryWidth: 30,
                    isCharging: batteryModel.isCharging,
                    isInLowPowerMode: batteryModel.isInLowPowerMode,
                    isPluggedIn: batteryModel.isPluggedIn,
                    levelBattery: batteryModel.levelBattery,
                    isForNotification: true
                )
            }
            .frame(width: 76, alignment: .trailing)
        }
        .frame(height: closedNotchHeight, alignment: .center)
    }

    @ViewBuilder
    private func inlineHUDContent(type: SneakContentType, value: CGFloat, icon: String) -> some View {
        InlineHUD(
            type: .constant(type),
            value: .constant(value),
            icon: .constant(icon),
            hoverAnimation: .constant(false),
            gestureProgress: .constant(0)
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private func sneakPeekOverlayContent(type: SneakContentType, value: CGFloat, icon: String) -> some View {
        if type == .music && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
            HStack(alignment: .center) {
                Image(systemName: "music.note")
                GeometryReader { geo in
                    if let musicService = pluginManager?.services.music, let track = musicService.currentTrack {
                        MarqueeText(
                            track.title + " - " + track.artist,
                            color: Defaults[.playerColorTinting]
                                ? Color(nsColor: musicService.avgColor).ensureMinimumBrightness(factor: 0.6)
                                : .gray,
                            delayDuration: 1.0,
                            frameWidth: geo.size.width
                        )
                    }
                }
            }
            .foregroundStyle(Color.gray)
            .padding(.bottom, 10)
        } else if type != .music && type != .battery {
            SystemEventIndicatorModifier(
                eventType: .constant(type),
                value: .constant(value),
                icon: .constant(icon),
                sendEventBack: { newVal in
                    switch type {
                    case .volume:
                        VolumeManager.shared.setAbsolute(Float32(newVal))
                    case .brightness:
                        BrightnessManager.shared.setAbsolute(value: Float32(newVal))
                    default:
                        break
                    }
                }
            )
            .padding(.bottom, 10)
            .padding(.leading, 4)
            .padding(.trailing, 8)
        }
    }

    // MARK: - Open Content

    @ViewBuilder
    private func openContent(_ view: NotchViews) -> some View {
        VStack(spacing: 0) {
            // Header should just clear the physical notch
            BoringHeader()
                .frame(height: max(
                    54, // Increased from 44 to prevent cutoff
                    (NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top
                        ?? NSScreen.main?.safeAreaInsets.top
                        ?? 0) + 10 // Add some breathing room
                ))

            switch view {
            case .home:
                NotchHomeView(albumArtNamespace: albumArtNamespace)
                    .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity, alignment: .top)
            case .shelf:
                ShelfView()
                    .environment(vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notifications:
                NotificationsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .clipboard:
                ClipboardView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notes:
                NotesView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sneak Peek / Expanding

    @ViewBuilder
    private func sneakPeekContent(type: SneakContentType, value: CGFloat, icon: String) -> some View {
        // Sneak peek content when notch state is not closed
        // This handles the sneakPeek case from NotchDisplayState
        EmptyView()
    }

    @ViewBuilder
    private func expandingContent(type: SneakContentType) -> some View {
        // Expanding view content
        EmptyView()
    }
}

// MARK: - Helper View for Face Animation

struct BoringFaceAnimation: View {
    var height: CGFloat

    var body: some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(
                        width: max(0, height - 12),
                        height: max(0, height - 12)
                    )
            }
            .overlay {
                MinimalFaceFeatures(
                    height: max(0, height - 12),
                    width: max(0, height - 6)
                )
            }
            .padding(.leading, 4)

            Rectangle()
                .fill(Color.clear)
                .frame(width: getClosedNotchSize().width)

            HStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(
                        width: max(0, height - 12),
                        height: max(0, height - 12)
                    )
            }
            .overlay {
                MinimalFaceFeatures(
                    height: max(0, height - 12),
                    width: max(0, height - 6)
                )
            }
            .padding(.trailing, 4)
        }
        .frame(height: height, alignment: .center)
    }
}

// MARK: - Music Live Activity Component

struct MusicLiveActivity: View {
    var musicService: (any MusicServiceProtocol)
    @Bindable var coordinator = BoringViewCoordinator.shared
    @Environment(BoringViewModel.self) var vm
    
    let albumArtNamespace: Namespace.ID
    var gestureProgress: CGFloat = 0
    var displayClosedNotchHeight: CGFloat
    var cornerRadiusScaleFactor: CGFloat?
    var cornerRadiusInsets: CornerRadiusInsets

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
                if let artwork = musicService.artwork {
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
                        .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
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
                    isPlaying: musicService.playbackState.isPlaying,
                    tintColor: Defaults[.coloredSpectrogram]
                    ? Color(nsColor: musicService.avgColor).ensureMinimumBrightness(factor: 0.5)
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

// MARK: - Preview Provider

#if DEBUG
struct NotchContentRouter_Previews: PreviewProvider {
    @Namespace static var namespace

    static var previews: some View {
        NotchContentRouter(
            displayState: NotchDisplayState.closed(content: NotchDisplayState.ClosedContent.idle),
            albumArtNamespace: namespace,
            coordinator: BoringViewCoordinator.shared,
            // musicManager: MusicManager.shared, // Removed
            batteryModel: BatteryStatusViewModel.shared,
            closedNotchHeight: CGFloat(32),
            cornerRadiusScaleFactor: 1.0,
            cornerRadiusInsets: CornerRadiusInsets(opened: (top: 19, bottom: 24), closed: (top: 6, bottom: 14))
        )
    }
}
#endif
