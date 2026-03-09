//
//  AmbientGlowVisualizer.swift
//  boringNotch
//
//  Soft ambient gradient that pulses below the closed notch when music plays.
//  Phase 12.0 — first visualizer mode (gradient glow).
//

import SwiftUI

struct AmbientGlowVisualizer: View {
    let albumColor: Color
    let isPlaying: Bool
    let height: CGFloat

    var body: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                gradientCanvas(time: t)
            }
            .frame(height: height)
            .clipped()
        }
    }

    @ViewBuilder
    private func gradientCanvas(time: Double) -> some View {
        // Three overlapping sine waves at different frequencies create organic movement
        let slow = (sin(time * 0.8) + 1) / 2          // ~4s cycle
        let medium = (sin(time * 1.5 + 1.2) + 1) / 2  // ~4.2s cycle, phase-shifted
        let fast = (sin(time * 2.3 + 2.8) + 1) / 2    // ~2.7s cycle, phase-shifted

        let baseOpacity = 0.15 + slow * 0.15           // 0.15–0.30
        let spreadFactor = 0.3 + medium * 0.2          // 0.3–0.5

        ZStack {
            // Primary radial glow from center-top (where notch is)
            RadialGradient(
                colors: [
                    albumColor.opacity(baseOpacity + fast * 0.08),
                    albumColor.opacity(baseOpacity * 0.5),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: height * (1.5 + spreadFactor)
            )

            // Secondary side lobes for width
            RadialGradient(
                colors: [
                    albumColor.opacity(baseOpacity * 0.6),
                    .clear
                ],
                center: UnitPoint(x: 0.3 - medium * 0.05, y: 0.1),
                startRadius: 0,
                endRadius: height * 1.2
            )

            RadialGradient(
                colors: [
                    albumColor.opacity(baseOpacity * 0.6),
                    .clear
                ],
                center: UnitPoint(x: 0.7 + medium * 0.05, y: 0.1),
                startRadius: 0,
                endRadius: height * 1.2
            )
        }
        .blur(radius: 8)
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 0) {
            Rectangle()
                .fill(.black)
                .frame(width: 300, height: 38)
            AmbientGlowVisualizer(
                albumColor: .purple,
                isPlaying: true,
                height: 30
            )
            .frame(width: 300)
        }
    }
    .frame(width: 400, height: 200)
}
