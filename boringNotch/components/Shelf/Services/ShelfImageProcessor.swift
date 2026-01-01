//
//  ShelfImageProcessor.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import Foundation
import AppKit
import SwiftUI

@MainActor
final class ShelfImageProcessor {
    static let shared = ShelfImageProcessor()
    
    // MARK: - Image Operations
    
    func removeBackground(from item: ShelfItem, completion: @escaping (Error?) -> Void) {
        guard let fileURL = item.fileURL, ImageProcessingService.shared.isImageFile(fileURL) else {
            completion(nil) // Or error
            return
        }
        
        Task {
            do {
                let resultURL = try await fileURL.accessSecurityScopedResource { url in
                    try await ImageProcessingService.shared.removeBackground(from: url)
                }
                
                if let resultURL = resultURL {
                    // Create bookmark and add to shelf as temporary item
                    if let bookmark = try? Bookmark(url: resultURL) {
                        let newItem = ShelfItem(
                            kind: .file(bookmark: bookmark.data),
                            isTemporary: true
                        )
                        ShelfStateViewModel.shared.add([newItem])
                    }
                }
                completion(nil)
            } catch {
                print("❌ Failed to remove background: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func createPDF(from items: [ShelfItem], completion: @escaping (Error?) -> Void) {
        let imageURLs = items.compactMap { $0.fileURL }.filter { ImageProcessingService.shared.isImageFile($0) }
        guard !imageURLs.isEmpty else { return }
        
        Task {
            do {
                let resultURL = try await imageURLs.accessSecurityScopedResources { urls in
                    try await ImageProcessingService.shared.createPDF(from: urls)
                }
                
                if let resultURL = resultURL {
                    if let bookmark = try? Bookmark(url: resultURL) {
                        let newItem = ShelfItem(
                            kind: .file(bookmark: bookmark.data),
                            isTemporary: true
                        )
                        ShelfStateViewModel.shared.add([newItem])
                    }
                }
                completion(nil)
            } catch {
                print("❌ Failed to create PDF: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func convertImage(item: ShelfItem, options: ImageConversionOptions, completion: @escaping (Error?) -> Void) {
        guard let fileURL = item.fileURL, ImageProcessingService.shared.isImageFile(fileURL) else { return }
        
        Task {
            do {
                let resultURL = try await fileURL.accessSecurityScopedResource { url in
                    try await ImageProcessingService.shared.convertImage(from: url, options: options)
                }
                
                if let resultURL = resultURL {
                    if let bookmark = try? Bookmark(url: resultURL) {
                        let newItem = ShelfItem(
                            kind: .file(bookmark: bookmark.data),
                            isTemporary: true
                        )
                        ShelfStateViewModel.shared.add([newItem])
                    }
                }
                completion(nil)
            } catch {
                print("❌ Failed to convert image: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func loadThumbnail(for url: URL, size: CGSize = CGSize(width: 56, height: 56)) async -> NSImage? {
        if let image = await ThumbnailService.shared.thumbnail(for: url, size: size) {
            return NSImage(cgImage: image, size: size)
        }
        return nil
    }
    
    func isImageFile(_ url: URL) -> Bool {
        return ImageProcessingService.shared.isImageFile(url)
    }
}
