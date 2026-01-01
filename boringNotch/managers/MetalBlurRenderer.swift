//
//  MetalBlurRenderer.swift
//  boringNotch
//
//  Deprecated. Replaced by SwiftGlass integration.
//  Kept for file reference compatibility.
//

import Foundation

// Empty class to satisfy any potential lingering references
@MainActor
final class MetalBlurRenderer: ObservableObject {
    static let shared = MetalBlurRenderer()
    private init() {}
}
