//
//  AmbientGlowVisualizer.swift
//  boringNotch
//
//  Endel-inspired generative visualization below the closed notch.
//  Canvas-based for performance — particles, orbital curves, and waves.
//

import SwiftUI

struct AmbientGlowVisualizer: View {
    let albumColor: Color
    let isPlaying: Bool
    let height: CGFloat

    var body: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                Canvas { context, size in
                    draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .frame(height: height)
            .clipped()
        }
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        drawWaves(in: &ctx, size: size, time: time)
        drawOrbits(in: &ctx, size: size, time: time)
        drawSweep(in: &ctx, size: size, time: time)
        drawParticles(in: &ctx, size: size, time: time)
    }

    // MARK: - Undulating waves (bottom region, very subtle)

    private func drawWaves(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        for layer in 0..<3 {
            let seed = Double(layer) * 1.3
            let yBase = size.height * (0.6 + Double(layer) * 0.13)
            let amp = size.height * 0.035
            let freq = 0.012 + Double(layer) * 0.004
            let spd = 0.25 + seed * 0.08

            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            for x in stride(from: 0, through: size.width, by: 3) {
                let y = yBase
                    + sin(x * freq + time * spd + seed) * amp
                    + cos(x * freq * 0.6 + time * spd * 0.4) * amp * 0.5
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()

            ctx.fill(path, with: .color(albumColor.opacity(0.04 + Double(layer) * 0.02)))
        }
    }

    // MARK: - Orbital elliptical curves

    private func drawOrbits(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<2 {
            let seed = Double(i) * 2.71
            let cx = size.width * 0.5
            let cy = size.height * (0.3 + Double(i) * 0.12)
            let rx = size.width * (0.3 + sin(time * 0.07 + seed) * 0.1)
            let ry = size.height * (0.1 + cos(time * 0.05 + seed) * 0.04)
            let rot = time * 0.04 * (i == 0 ? 1.0 : -1.0) + seed
            let arcLen = Double.pi * 1.5 + sin(time * 0.08 + seed) * 0.4

            var path = Path()
            let steps = 60
            for j in 0...steps {
                let t = Double(j) / Double(steps) * arcLen
                let px = cx + cos(t + rot) * rx
                let py = cy + sin(t + rot) * ry
                if j == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }

            let alpha = 0.1 + sin(time * 0.15 + seed) * 0.05
            ctx.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 0.8)
        }
    }

    // MARK: - Sweeping bezier curve

    private func drawSweep(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let phase = time * 0.03
        let startX = size.width * (0.05 + sin(phase) * 0.1)
        let startY = size.height * (0.45 + cos(phase * 0.7) * 0.1)
        let endX = size.width * (0.95 + cos(phase * 0.8) * 0.1)
        let endY = size.height * (0.7 + sin(phase * 1.1) * 0.15)
        let cp1 = CGPoint(x: size.width * 0.35, y: size.height * (0.25 + sin(phase * 0.6) * 0.15))
        let cp2 = CGPoint(x: size.width * 0.7, y: size.height * (0.8 + cos(phase * 0.9) * 0.1))

        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addCurve(to: CGPoint(x: endX, y: endY), control1: cp1, control2: cp2)

        ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1.0)
    }

    // MARK: - Floating particles (rings + dots)

    private func drawParticles(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<16 {
            let seed = Double(i) * 1.618
            let x = size.width * (0.08 + 0.84 * (sin(time * 0.04 * (1 + seed * 0.07) + seed * 2.1) + 1) / 2)
            let y = size.height * (0.05 + 0.9 * (cos(time * 0.03 * (1 + seed * 0.06) + seed * 1.7) + 1) / 2)
            let r = 2.0 + sin(seed * 3.14) * 2.5
            let isRing = i % 3 != 0
            let alpha = 0.15 + sin(time * 0.25 + seed * 0.7) * 0.12

            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            let circle = Circle().path(in: rect)

            if isRing {
                ctx.stroke(circle, with: .color(.white.opacity(alpha)), lineWidth: 1)
            } else {
                ctx.fill(circle, with: .color(albumColor.opacity(alpha)))
            }
        }
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
                height: 160
            )
            .frame(width: 300)
        }
    }
    .frame(width: 400, height: 300)
}
