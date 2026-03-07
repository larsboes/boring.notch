import SwiftUI

/// Closed-notch teleprompter display — the primary reading view.
/// The notch extends well below camera level, giving a generous reading area
/// right below the camera for natural eye contact.
struct TeleprompterClosedView: View {
    let state: TeleprompterState

    @Environment(BoringViewModel.self) var vm
    @Environment(\.displayClosedNotchHeight) var displayClosedNotchHeight

    /// Real notch height (camera area) — keep text out of this zone
    private var cameraZoneHeight: CGFloat {
        getRealNotchHeight()
    }

    /// The reading area below the camera
    private var readingAreaHeight: CGFloat {
        max(0, displayClosedNotchHeight - cameraZoneHeight)
    }

    /// Match closed notch width + flanking (same pattern as MusicLiveActivity)
    private var contentWidth: CGFloat {
        vm.closedNotchSize.width + 60
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top zone — physical notch area (camera lives here, stay clear)
            Color.clear
                .frame(height: cameraZoneHeight)

            // Reading zone — teleprompter text, directly below camera
            ZStack {
                // Background Voice Glow Beam (Only active while scrolling/playing)
                if state.isScrolling {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.indigo.opacity(0.6),
                                    Color.purple.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        // Scale the height based on vocal input
                        .frame(height: max(10, readingAreaHeight * state.micMonitor.normalizedLevel))
                        // Fade in on voice, but keep a dim glow otherwise
                        .opacity(0.2 + (state.micMonitor.normalizedLevel * 0.8))
                        // Aggressive blurred blend for glass aesthetic
                        .blur(radius: 12)
                        .blendMode(.screen)
                        // Top aligned so it beams out directly from beneath the notch
                        .frame(maxHeight: .infinity, alignment: .top)
                        .animation(.interpolatingSpring(stiffness: 120, damping: 14), value: state.micMonitor.normalizedLevel)
                }

                if state.text.isEmpty {
                    Text("No script loaded")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        Text(state.text)
                            .font(.system(
                                size: state.config.fontSize,
                                weight: .medium,
                                design: .default
                            ))
                            .foregroundStyle(state.textColor.color.opacity(0.95))
                            .lineSpacing(8)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: contentWidth - 32)
                            .padding(.top, 8)
                            .padding(.bottom, readingAreaHeight) // Allow scrolling past the end
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: TeleprompterContentHeightKey.self, value: geo.size.height)
                                }
                            )
                            .offset(y: -state.scrollPosition)
                    }
                    .scrollDisabled(true)
                    .scrollIndicators(.never)
                    // Hover-to-pause mechanic
                    .onHover { hovering in
                        state.isHovering = hovering
                    }
                    .onPreferenceChange(TeleprompterContentHeightKey.self) { height in
                        // Record actual rendered height so state knows when to stop scrolling
                        if abs(state.contentHeight - Double(height)) > 1.0 {
                            // Run async to avoid modifying state during view update
                            Task { @MainActor in
                                state.contentHeight = Double(height)
                            }
                        }
                    }
                }
            }
            .frame(width: contentWidth, height: readingAreaHeight)
            .clipped()
        }
        .frame(width: contentWidth, height: displayClosedNotchHeight)
        .overlay {
            if state.countdownState.isActive {
                CountdownOverlayView(state: state.countdownState)
            }
        }
    }
}

// MARK: - Preference Key

struct TeleprompterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
