//
//  LiquidGlass.swift
//  boringNotch
//
//  Created for iOS 26-style liquid glass effect.
//  Provides a toggleable frosted glass appearance for the notch.
//

import SwiftUI
import AppKit

// MARK: - Glass Style Configuration

/// Configuration for the liquid glass effect appearance
struct LiquidGlassConfiguration {
    /// Material blur intensity
    var material: NSVisualEffectView.Material = .hudWindow
    
    /// Blending mode for the glass effect
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    /// Opacity of the base tint color
    var tintOpacity: CGFloat = 0.15
    
    /// Opacity of the luminous border
    var borderOpacity: CGFloat = 0.4
    
    /// Border width
    var borderWidth: CGFloat = 0.5
    
    /// Inner glow/highlight intensity
    var innerGlowOpacity: CGFloat = 0.1
    
    /// Whether to show specular highlights
    var showSpecularHighlight: Bool = true
    
    /// Depth shadow opacity for Vision Pro-like depth
    var depthShadowOpacity: CGFloat = 0.2
    
    /// Ambient light intensity
    var ambientLightOpacity: CGFloat = 0.08
    
    /// Edge glow intensity for more pronounced borders
    var edgeGlowOpacity: CGFloat = 0.3
    
    /// Default configuration
    static let `default` = LiquidGlassConfiguration()
    
    /// Subtle configuration for less intense effect
    static let subtle = LiquidGlassConfiguration(
        tintOpacity: 0.1,
        borderOpacity: 0.25,
        innerGlowOpacity: 0.05,
        depthShadowOpacity: 0.1,
        ambientLightOpacity: 0.04,
        edgeGlowOpacity: 0.15
    )
    
    /// Vibrant configuration for more visible effect
    static let vibrant = LiquidGlassConfiguration(
        tintOpacity: 0.2,
        borderOpacity: 0.5,
        borderWidth: 1.0,
        innerGlowOpacity: 0.15,
        depthShadowOpacity: 0.3,
        ambientLightOpacity: 0.12,
        edgeGlowOpacity: 0.4
    )
}

// MARK: - NSVisualEffectView Wrapper

/// A SwiftUI wrapper for NSVisualEffectView that provides blur effects
struct GlassEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var isActive: Bool = true
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = isActive ? .active : .inactive
        view.isEmphasized = true
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = isActive ? .active : .inactive
    }
}

// MARK: - Liquid Glass Background View

/// The main liquid glass background component
struct LiquidGlassBackground<S: Shape>: View {
    let shape: S
    var configuration: LiquidGlassConfiguration = .default
    var isActive: Bool = true
    
    /// Optional tint color sampled from content (e.g., album art)
    var tintColor: Color?
    
    var body: some View {
        if isActive {
            ZStack {
                // Layer 1: Base blur effect (Vision Pro-style material)
                GlassEffectView(
                    material: configuration.material,
                    blendingMode: configuration.blendingMode,
                    isActive: true
                )
                .clipShape(shape)
                
                // Layer 2: Ambient light base (Vision Pro-style ambient lighting)
                shape
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(configuration.ambientLightOpacity),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                
                // Layer 3: Dark tint for contrast and depth (reduced for better content visibility)
                shape
                    .fill(Color.black.opacity(0.15))
                
                // Layer 4: Optional color tint from content (enhanced for Vision Pro)
                if let tint = tintColor {
                    shape
                        .fill(
                            RadialGradient(
                                colors: [
                                    tint.opacity(configuration.tintOpacity * 1.5),
                                    tint.opacity(configuration.tintOpacity * 0.5),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .blendMode(.plusLighter)
                }
                
                // Layer 5: Inner highlight/glow (top-left light source simulation - Vision Pro style)
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.innerGlowOpacity * 1.2),
                                .white.opacity(configuration.innerGlowOpacity * 0.6),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.7, y: 0.7)
                        )
                    )
                    .blendMode(.plusLighter)
                
                // Layer 6: Specular highlight (enhanced for Vision Pro depth)
                if configuration.showSpecularHighlight {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .white.opacity(0.08),
                                    .white.opacity(0.03),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.6)
                            )
                        )
                        .mask(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                }
                
                // Layer 7: Edge glow for Vision Pro-style luminous edges
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.edgeGlowOpacity),
                                .white.opacity(configuration.edgeGlowOpacity * 0.4),
                                .white.opacity(configuration.edgeGlowOpacity * 0.6),
                                .white.opacity(configuration.edgeGlowOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: configuration.borderWidth
                    )
                    .blur(radius: 0.5)
                
                // Layer 8: Luminous border (refined for Vision Pro)
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.borderOpacity),
                                .white.opacity(configuration.borderOpacity * 0.4),
                                .white.opacity(configuration.borderOpacity * 0.6),
                                .white.opacity(configuration.borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: configuration.borderWidth
                    )
            }
        } else {
            // Fallback to solid black when glass effect is disabled
            shape
                .fill(Color.black)
        }
    }
}

// MARK: - View Modifier

/// A view modifier that applies the liquid glass effect
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let isEnabled: Bool
    var configuration: LiquidGlassConfiguration = .default
    var tintColor: Color?
    
    func body(content: Content) -> some View {
        content
            .background {
                LiquidGlassBackground(
                    shape: shape,
                    configuration: configuration,
                    isActive: isEnabled,
                    tintColor: tintColor
                )
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a liquid glass background effect to the view
    /// - Parameters:
    ///   - shape: The shape to use for the glass effect
    ///   - isEnabled: Whether the glass effect is enabled
    ///   - configuration: The glass effect configuration
    ///   - tintColor: Optional tint color to blend with the glass
    /// - Returns: A view with the liquid glass effect applied
    func liquidGlass<S: Shape>(
        _ shape: S,
        isEnabled: Bool = true,
        configuration: LiquidGlassConfiguration = .default,
        tintColor: Color? = nil
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                shape: shape,
                isEnabled: isEnabled,
                configuration: configuration,
                tintColor: tintColor
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidGlass_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Simulated desktop background
            LinearGradient(
                colors: [.blue, .purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Glass panel example
            VStack {
                Text("Liquid Glass Effect")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("This shows the frosted glass appearance")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .liquidGlass(
                RoundedRectangle(cornerRadius: 24),
                isEnabled: true,
                configuration: .default
            )
        }
        .frame(width: 400, height: 300)
    }
}
#endif
