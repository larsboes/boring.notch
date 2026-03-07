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
                            .padding(.bottom, readingAreaHeight)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: TeleprompterContentHeightKey.self, value: geo.size.height)
                                }
                            )
                            .offset(y: -state.scrollPosition)
                    }
                    .scrollDisabled(true)
                    .scrollIndicators(.never)
                    // Karaoke fade — top lines bright, fading down
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.35),
                                .init(color: .white.opacity(0.5), location: 0.65),
                                .init(color: .clear, location: 0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onHover { hovering in
                        state.isHovering = hovering
                    }
                    .onPreferenceChange(TeleprompterContentHeightKey.self) { height in
                        if abs(state.contentHeight - Double(height)) > 1.0 {
                            Task { @MainActor in
                                state.contentHeight = Double(height)
                            }
                        }
                    }
                }
            }
            .frame(width: contentWidth, height: readingAreaHeight)
            .clipped()
            .overlay(alignment: .bottom) {
                if !state.text.isEmpty {
                    readingChrome
                }
            }
        }
        .frame(width: contentWidth, height: displayClosedNotchHeight)
        .overlay {
            if state.countdownState.isActive {
                CountdownOverlayView(state: state.countdownState)
            }
        }
        .onDisappear {
            state.timerManager.micMonitor.stopMonitoring()
        }
        .onChange(of: vm.notchState) {
            if vm.notchState != .closed {
                state.timerManager.micMonitor.stopMonitoring()
            }
        }
    }

    // MARK: - Reading Chrome

    /// Progress bar, section title, and elapsed/remaining time overlay.
    private var readingChrome: some View {
        VStack(spacing: 0) {
            // Section title (top-right of reading zone)
            HStack {
                Spacer()
                if let section = state.currentSectionTitle {
                    Text(section)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                }
            }

            Spacer()

            // Elapsed / remaining time
            if state.isScrolling || state.scrollPosition > 0 {
                HStack {
                    Text(state.elapsedTimeString)
                    Spacer()
                    Text(state.remainingTimeString)
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 2)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.5))
                            .frame(width: geo.size.width * state.progress)
                    }
            }
            .frame(height: 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preference Key

struct TeleprompterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
