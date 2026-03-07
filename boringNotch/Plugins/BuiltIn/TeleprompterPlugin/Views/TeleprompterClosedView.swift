import SwiftUI

/// Closed-notch teleprompter display — the primary reading view.
/// Uses double the physical notch height: top half = physical notch area (camera),
/// bottom half = scrolling text right below the camera for eye contact.
struct TeleprompterClosedView: View {
    let state: TeleprompterState

    @Environment(BoringViewModel.self) var vm
    @Environment(\.displayClosedNotchHeight) var displayClosedNotchHeight

    /// Physical notch height is half of the total display height
    private var physicalNotchHeight: CGFloat {
        displayClosedNotchHeight / 2
    }

    /// Match closed notch width + flanking (same pattern as MusicLiveActivity)
    private var contentWidth: CGFloat {
        vm.closedNotchSize.width + 60
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top half — physical notch area (camera lives here, stay clear)
            Color.clear
                .frame(height: physicalNotchHeight)

            // Bottom half — teleprompter text, centered below camera
            ZStack {
                if state.text.isEmpty {
                    Text("No script loaded")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    // Current line with crossfade transition
                    Text(currentLine)
                        .font(.system(
                            size: min(14, physicalNotchHeight * 0.38),
                            weight: .medium,
                            design: .default
                        ))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: contentWidth - 40)
                        .id(currentLineIndex) // force view identity change for transition
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                        .animation(.easeInOut(duration: 0.4), value: currentLineIndex)
                }
            }
            .frame(width: contentWidth, height: physicalNotchHeight)
            .clipped()
        }
        .frame(width: contentWidth, height: displayClosedNotchHeight)
    }

    // MARK: - Line Calculation

    /// All non-empty lines in the script
    private var lines: [String] {
        state.text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Virtual line height in scroll-pixels.
    /// Controls reading pace: readingTime = pixelsPerLine / speed.
    /// At 100px and speed 30: ~3.3s per line. At speed 50: ~2s per line.
    private static let pixelsPerLine: Double = 100

    /// Current line index based on scroll position
    private var currentLineIndex: Int {
        guard !lines.isEmpty else { return 0 }
        let raw = Int(state.scrollPosition / Self.pixelsPerLine)
        return min(raw, lines.count - 1)
    }

    /// The text of the current line
    private var currentLine: String {
        guard !lines.isEmpty else { return "" }
        return lines[currentLineIndex]
    }
}
