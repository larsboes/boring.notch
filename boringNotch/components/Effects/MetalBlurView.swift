//
//  MetalBlurView.swift
//  boringNotch
//
//  Metal Liquid Glass - SwiftUI wrapper for Metal-rendered blur.
//  Displays the blurred desktop texture as a background for the notch.
//

import SwiftUI
import MetalKit
import AppKit

/// SwiftUI view that renders the Metal-blurred desktop texture
struct MetalBlurView: NSViewRepresentable {
    /// Blur radius for the effect
    let blurRadius: Float
    
    /// The screen to capture
    let screen: NSScreen?
    
    /// The window to exclude from capture
    let excludingWindow: NSWindow?
    
    /// Capture region in screen coordinates
    let captureRect: CGRect
    
    /// Whether the effect is active
    let isActive: Bool
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        // Get Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MetalBlurView: No Metal device available")
            return mtkView
        }
        
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.layer?.isOpaque = false
        
        // Reduce draw calls - we update when we have new frames
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.blurRadius = blurRadius
        context.coordinator.isActive = isActive
        context.coordinator.captureRect = captureRect
        
        if isActive, let screen = screen {
            context.coordinator.startCapture(
                screen: screen,
                excludingWindow: excludingWindow,
                captureRect: captureRect
            )
        } else {
            context.coordinator.stopCapture()
        }
        
        // Trigger redraw
        nsView.setNeedsDisplay(nsView.bounds)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(blurRadius: blurRadius)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MTKViewDelegate {
        var blurRadius: Float
        var isActive: Bool = false
        var captureRect: CGRect = .zero
        
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var currentTexture: MTLTexture?
        private var captureTask: Task<Void, Never>?
        
        init(blurRadius: Float) {
            self.blurRadius = blurRadius
            super.init()
            setupMetal()
        }
        
        private func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            commandQueue = device.makeCommandQueue()
            
            // Create simple texture rendering pipeline
            let library = device.makeDefaultLibrary()
            
            // If we have shader functions, create pipeline
            // For now, we'll use a simple blit approach
        }
        
        func startCapture(screen: NSScreen, excludingWindow: NSWindow?, captureRect: CGRect) {
            // Stop existing capture
            stopCapture()
            
            captureTask = Task { @MainActor in
                await LiquidGlassManager.shared.start(
                    screen: screen,
                    excludingWindow: excludingWindow,
                    captureRect: captureRect,
                    blurRadius: blurRadius
                )
            }
        }
        
        func stopCapture() {
            captureTask?.cancel()
            captureTask = nil
            
            Task { @MainActor in
                await LiquidGlassManager.shared.stop()
            }
        }
        
        // MARK: - MTKViewDelegate
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            guard isActive else {
                // Clear to transparent when inactive
                guard let drawable = view.currentDrawable,
                      let commandBuffer = commandQueue?.makeCommandBuffer(),
                      let descriptor = view.currentRenderPassDescriptor else { return }
                
                descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
                descriptor.colorAttachments[0].loadAction = .clear
                
                if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
                    encoder.endEncoding()
                }
                
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            
            // Get the blurred texture from the manager
            guard let texture = LiquidGlassManager.shared.blurredTexture,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer() else {
                return
            }
            
            // Blit the blurred texture to the drawable
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
            
            let sourceSize = MTLSize(
                width: min(texture.width, drawable.texture.width),
                height: min(texture.height, drawable.texture.height),
                depth: 1
            )
            
            blitEncoder?.copy(
                from: texture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: sourceSize,
                to: drawable.texture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            
            blitEncoder?.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
            currentTexture = texture
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct MetalBlurView_Previews: PreviewProvider {
    static var previews: some View {
        MetalBlurView(
            blurRadius: 20,
            screen: NSScreen.main,
            excludingWindow: nil,
            captureRect: CGRect(x: 0, y: 0, width: 400, height: 200),
            isActive: false
        )
        .frame(width: 400, height: 200)
        .background(Color.black)
    }
}
#endif
