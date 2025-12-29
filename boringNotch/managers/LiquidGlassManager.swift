//
//  LiquidGlassManager.swift
//  boringNotch
//
//  Metal Liquid Glass - Orchestrates capture, blur, and rendering.
//  Manages the lifecycle of desktop capture and blur rendering for the liquid glass effect.
//

import AppKit
import Combine
import SwiftUI
import CoreVideo
import Metal

/// Manages the Metal-based liquid glass effect lifecycle.
/// Coordinates between DesktopCaptureActor and MetalBlurRenderer.
@MainActor
final class LiquidGlassManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = LiquidGlassManager()
    
    // MARK: - Published State
    
    /// Whether the liquid glass effect is currently active
    @Published private(set) var isActive = false
    
    /// Whether screen recording permission is granted
    @Published private(set) var hasPermission = false
    
    /// The latest blurred texture (for rendering)
    @Published private(set) var blurredTexture: MTLTexture?
    
    /// The latest blurred image (for SwiftUI preview, optional)
    @Published private(set) var blurredImage: NSImage?
    
    /// Error message if initialization failed
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var captureActor: DesktopCaptureActor?
    private var blurRenderer: MetalBlurRenderer?
    private var captureTask: Task<Void, Never>?
    private var currentScreen: NSScreen?
    private var currentWindow: NSWindow?
    
    /// Current blur radius
    var blurRadius: Float = 20.0 {
        didSet {
            blurRenderer?.blurRadius = blurRadius
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Check permission on init
        Task {
            await checkPermission()
        }
    }
    
    // MARK: - Permission Management
    
    /// Check if screen recording is authorized
    func checkPermission() async {
        hasPermission = await DesktopCaptureActor.isAuthorized()
    }
    
    /// Request screen recording permission
    func requestPermission() async -> Bool {
        let granted = await DesktopCaptureActor.requestPermission()
        hasPermission = granted
        return granted
    }
    
    // MARK: - Lifecycle
    
    /// Start the liquid glass effect for a screen
    /// - Parameters:
    ///   - screen: The screen to capture
    ///   - window: The notch window to exclude from capture
    ///   - captureRect: The region to capture (notch area)
    ///   - blurRadius: Blur intensity
    func start(
        screen: NSScreen,
        excludingWindow window: NSWindow?,
        captureRect: CGRect,
        blurRadius: Float = 20.0
    ) async {
        // Stop existing capture first
        await stop()
        
        // Check permission
        if !hasPermission {
            // Request permission
            let granted = await requestPermission()
            if !granted {
                errorMessage = "Screen recording permission required for Liquid Glass effect"
                return
            }
        }
        
        // Initialize renderer if needed
        if blurRenderer == nil {
            blurRenderer = MetalBlurRenderer(blurRadius: blurRadius)
            if blurRenderer == nil {
                errorMessage = "Failed to initialize Metal renderer"
                return
            }
        }
        
        self.blurRadius = blurRadius
        self.currentScreen = screen
        self.currentWindow = window
        
        // Create capture actor
        let actor = DesktopCaptureActor()
        self.captureActor = actor
        
        // Start capture
        do {
            try await actor.startCapture(
                screen: screen,
                excludingWindow: window,
                captureRect: captureRect,
                frameRate: 30
            )
            
            isActive = true
            errorMessage = nil
            
            // Start processing frames
            startFrameProcessing()
            
        } catch {
            errorMessage = "Failed to start capture: \(error.localizedDescription)"
            print("LiquidGlassManager: Start failed: \(error)")
        }
    }
    
    /// Stop the liquid glass effect
    func stop() async {
        // Cancel frame processing
        captureTask?.cancel()
        captureTask = nil
        
        // Stop capture
        if let actor = captureActor {
            await actor.stopCapture()
        }
        captureActor = nil
        
        // Clear state
        isActive = false
        blurredTexture = nil
        blurredImage = nil
        currentScreen = nil
        currentWindow = nil
    }
    
    /// Update capture region (when notch size changes)
    func updateCaptureRegion(_ rect: CGRect) async {
        guard let screen = currentScreen else { return }
        
        // Restart with new region
        await stop()
        await start(
            screen: screen,
            excludingWindow: currentWindow,
            captureRect: rect,
            blurRadius: blurRadius
        )
    }
    
    // MARK: - Frame Processing
    
    private func startFrameProcessing() {
        guard let actor = captureActor else { return }
        
        captureTask = Task { [weak self] in
            // Get the frame stream from the actor
            guard let frameStream = await actor.frameStream else {
                return
            }
            
            for await pixelBuffer in frameStream {
                guard !Task.isCancelled else { break }
                
                // Process frame on main actor
                await MainActor.run { [weak self] in
                    self?.processFrame(pixelBuffer)
                }
            }
        }
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let renderer = blurRenderer else { return }
        
        // Apply blur
        if let texture = renderer.blur(pixelBuffer: pixelBuffer) {
            blurredTexture = texture
            
            // Optionally create NSImage for SwiftUI preview (expensive, use sparingly)
            // self.blurredImage = texture.toNSImage()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        captureTask?.cancel()
    }
}

// MARK: - Convenience Methods

extension LiquidGlassManager {
    /// Calculate the capture rect for the notch based on screen and notch size
    static func captureRect(for screen: NSScreen, notchSize: CGSize) -> CGRect {
        let screenFrame = screen.frame
        
        // Notch is centered at top of screen
        let x = (screenFrame.width - notchSize.width) / 2
        let y = screenFrame.height - notchSize.height
        
        return CGRect(
            x: x,
            y: y,
            width: notchSize.width,
            height: notchSize.height
        )
    }
}
