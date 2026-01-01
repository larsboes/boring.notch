//
//  ShelfDropHandler.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ShelfDropHandler {
    static let shared = ShelfDropHandler()
    
    func dragItemProvider(for item: ShelfItem, selection: ShelfSelectionModel) -> NSItemProvider {
        let selectedItems = selection.selectedItems(in: ShelfStateViewModel.shared.items)
        if selectedItems.count > 1 && selectedItems.contains(where: { $0.id == item.id }) {
            return createMultiItemProvider(for: selectedItems)
        }
        return createItemProvider(for: item)
    }

    private func createItemProvider(for item: ShelfItem) -> NSItemProvider {
        switch item.kind {
        case .file:
            let provider = NSItemProvider()
            if let url = ShelfStateViewModel.shared.resolveAndUpdateBookmark(for: item) {
                provider.registerObject(url as NSURL, visibility: .all)
            } else {
                provider.registerObject(item.displayName as NSString, visibility: .all)
            }
            return provider
        case .text(let string):
            return NSItemProvider(object: string as NSString)
        case .link(let url):
            return NSItemProvider(object: url as NSURL)
        }
    }

    private func createMultiItemProvider(for items: [ShelfItem]) -> NSItemProvider {
        let provider = NSItemProvider()
        var urls: [URL] = []
        var textItems: [String] = []
        for item in items {
            switch item.kind {
            case .file:
                if let url = ShelfStateViewModel.shared.resolveAndUpdateBookmark(for: item) {
                    urls.append(url)
                } else {
                    textItems.append(item.displayName)
                }
            case .text(let string):
                textItems.append(string)
            case .link:
                break
            }
        }
        if !urls.isEmpty {
            for url in urls {
                provider.registerObject(url as NSURL, visibility: .all)
            }
        }
        if !textItems.isEmpty {
            provider.registerObject(textItems.joined(separator: "\n") as NSString, visibility: .all)
        }
        return provider
    }
}
