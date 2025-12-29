//
//  MetalBlurRenderer.swift
//  boringNotch
//
//  Metal Liquid Glass - GPU-accelerated Gaussian blur using Metal Performance Shaders.
//  Processes CVPixelBuffer frames from DesktopCaptureActor and outputs blurred MTLTextures.
//

import Metal
import MetalKit
import MetalPerformanceShaders
import CoreVideo
import AppKit

/// GPU-accelerated blur renderer using Metal Performance Shaders.
/// Converts CVPixelBuffer input to blurred MTLTexture output.
@MainActor
final class MetalBlurRenderer {
    // MARK: - Properties
    
    /// The Metal device (GPU)
    private let device: MTLDevice
    
    /// Command queue for submitting GPU work
    private let commandQueue: MTLCommandQueue
    
    /// Gaussian blur kernel
    private var blurKernel: MPSImageGaussianBlur
    
    /// Texture cache for efficient CVPixelBuffer to MTLTexture conversion
    private var textureCache: CVMetalTextureCache?
    
    /// Current blur radius (sigma value for Gaussian blur)
    var blurRadius: Float {
        didSet {
            // Recreate kernel with new sigma
            blurKernel = MPSImageGaussianBlur(device: device, sigma: blurRadius)
        }
    }
    
    /// Optional output texture (reused for efficiency)
    private var outputTexture: MTLTexture?
    private var lastSize: CGSize = .zero
    
    // MARK: - Initialization
    
    /// Initialize the Metal blur renderer
    /// - Parameter blurRadius: Initial blur radius (sigma), default 20.0
    init?(blurRadius: Float = 20.0) {
        // Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MetalBlurRenderer: No Metal device available")
            return nil
        }
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("MetalBlurRenderer: Failed to create command queue")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.blurRadius = blurRadius
        
        // Create Gaussian blur kernel
        self.blurKernel = MPSImageGaussianBlur(device: device, sigma: blurRadius)
        
        // Edge mode - clamp to edge to avoid artifacts
        blurKernel.edgeMode = .clamp
        
        // Create texture cache for CVPixelBuffer conversion
        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        
        if result != kCVReturnSuccess {
            print("MetalBlurRenderer: Failed to create texture cache")
            return nil
        }
        
        self.textureCache = cache
        
        print("MetalBlurRenderer: Initialized with blur radius \(blurRadius)")
    }
    
    // MARK: - Public Methods
    
    /// Apply Gaussian blur to a CVPixelBuffer
    /// - Parameters:
    ///   - pixelBuffer: Input pixel buffer from screen capture
    ///   - sigma: Optional blur radius override
    /// - Returns: Blurred MTLTexture, or nil if processing failed
    func blur(pixelBuffer: CVPixelBuffer, sigma: Float? = nil) -> MTLTexture? {
        // Update blur radius if provided
        if let sigma = sigma, sigma != blurRadius {
            blurRadius = sigma
        }
        
        // Convert CVPixelBuffer to MTLTexture
        guard let sourceTexture = createTexture(from: pixelBuffer) else {
            return nil
        }
        
        // Get or create output texture with matching size
        let size = CGSize(
            width: CGFloat(sourceTexture.width),
            height: CGFloat(sourceTexture.height)
        )
        
        let destTexture = getOutputTexture(size: size)
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("MetalBlurRenderer: Failed to create command buffer")
            return nil
        }
        
        // Encode blur operation
        blurKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destTexture
        )
        
        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return destTexture
    }
    
    /// Apply blur and return immediately (async version)
    /// - Parameters:
    ///   - pixelBuffer: Input pixel buffer
    ///   - completion: Callback with blurred texture
    func blurAsync(pixelBuffer: CVPixelBuffer, completion: @escaping (MTLTexture?) -> Void) {
        guard let sourceTexture = createTexture(from: pixelBuffer) else {
            completion(nil)
            return
        }
        
        let size = CGSize(
            width: CGFloat(sourceTexture.width),
            height: CGFloat(sourceTexture.height)
        )
        
        let destTexture = getOutputTexture(size: size)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            completion(nil)
            return
        }
        
        blurKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destTexture
        )
        
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                completion(destTexture)
            }
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Private Methods
    
    /// Convert CVPixelBuffer to MTLTexture using texture cache
    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        guard result == kCVReturnSuccess, let cvTexture = cvTexture else {
            print("MetalBlurRenderer: Failed to create texture from pixel buffer")
            return nil
        }
        
        return CVMetalTextureGetTexture(cvTexture)
    }
    
    /// Get or create output texture with the specified size
    private func getOutputTexture(size: CGSize) -> MTLTexture {
        // Reuse existing texture if size matches
        if let existing = outputTexture, size == lastSize {
            return existing
        }
        
        // Create new texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("MetalBlurRenderer: Failed to create output texture")
        }
        
        outputTexture = texture
        lastSize = size
        
        return texture
    }
    
    // MARK: - Cleanup
    
    /// Flush the texture cache to free memory
    func flushCache() {
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }
}

// MARK: - MTLTexture to NSImage Extension

extension MTLTexture {
    /// Convert MTLTexture to NSImage for debugging/preview
    func toNSImage() -> NSImage? {
        let width = self.width
        let height = self.height
        let bytesPerRow = width * 4
        
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        
        self.getBytes(
            &data,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                           size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}
