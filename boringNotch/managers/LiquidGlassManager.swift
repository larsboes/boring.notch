//
//  LiquidGlassManager.swift
//  boringNotch
//
//  Deprecated. Replaced by SwiftGlass integration.
//  Kept for file reference compatibility.
//

import Foundation
import Combine
import AppKit

// Empty class to satisfy any potential lingering references
@MainActor
final class LiquidGlassManager: ObservableObject {
    static let shared = LiquidGlassManager()
    
    @Published private(set) var isActive = false
    @Published private(set) var hasPermission = false
    
    private init() {}
    
    // Stub methods to prevent build errors if referenced
    func start(screen: NSScreen, excludingWindow window: NSWindow?, captureRect: CGRect, blurRadius: Float = 20.0) async {}
    func stop() async {}
    func updateCaptureRegion(_ rect: CGRect) async {}
    
    // Static helper that might still be referenced
    static func captureRect(for screen: NSScreen, notchSize: CGSize) -> CGRect {
        return .zero
    }
}
