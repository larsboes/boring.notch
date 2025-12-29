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
    
    /// Default configuration
    static let `default` = LiquidGlassConfiguration()
    
    /// Subtle configuration for less intense effect
    static let subtle = LiquidGlassConfiguration(
        tintOpacity: 0.1,
        borderOpacity: 0.25,
        innerGlowOpacity: 0.05
    )
    
    /// Vibrant configuration for more visible effect
    static let vibrant = LiquidGlassConfiguration(
        tintOpacity: 0.2,
        borderOpacity: 0.5,
        borderWidth: 1.0,
        innerGlowOpacity: 0.15
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
                // Layer 1: Base blur effect
                GlassEffectView(
                    material: configuration.material,
                    blendingMode: configuration.blendingMode,
                    isActive: true
                )
                .clipShape(shape)
                
                // Layer 2: Dark tint for contrast
                shape
                    .fill(Color.black.opacity(0.3))
                
                // Layer 3: Optional color tint from content
                if let tint = tintColor {
                    shape
                        .fill(tint.opacity(configuration.tintOpacity))
                }
                
                // Layer 4: Inner highlight/glow (top-left light source simulation)
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.innerGlowOpacity),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Layer 5: Specular highlight (simulates light reflection)
                if configuration.showSpecularHighlight {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.15),
                                    .white.opacity(0.05),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .mask(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                }
                
                // Layer 6: Luminous border
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.borderOpacity),
                                .white.opacity(configuration.borderOpacity * 0.3),
                                .white.opacity(configuration.borderOpacity * 0.5)
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
