//
//  ShelfItemViewModel.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CoreServices
import ObjectiveC

@MainActor
@Observable
final class ShelfItemViewModel {
    var item: ShelfItem
    var thumbnail: NSImage?
    var isDropTargeted: Bool = false
    var isRenaming: Bool = false
    var draftTitle: String = ""
    
    // Sharing state
    // Removed as sharing logic moved to QuickShareService

    private let selection = ShelfSelectionModel.shared
    
    // Services
    private let fileHandler = ShelfFileHandler.shared
    private let imageProcessor = ShelfImageProcessor.shared
    private let dropHandler = ShelfDropHandler.shared

    init(item: ShelfItem) {
        self.item = item
        self.draftTitle = item.displayName
        Task { await loadThumbnail() }
    }

    var isSelected: Bool { selection.isSelected(item.id) }

    func loadThumbnail() async {
        guard let url = item.fileURL else { return }
        self.thumbnail = await imageProcessor.loadThumbnail(for: url)
    }

    // MARK: - Drag & Drop helpers
    func dragItemProvider() -> NSItemProvider {
        return dropHandler.dragItemProvider(for: item, selection: selection)
    }

    // MARK: - Actions
    func handleClick(event: NSEvent, view: NSView) {
        let flags = event.modifierFlags
        if flags.contains(.shift) {
            selection.shiftSelect(to: item, in: ShelfStateViewModel.shared.items)
        } else if flags.contains(.command) {
            selection.toggle(item)
        } else if flags.contains(.control) {
            handleRightClick(event: event, view: view)
        } else {
            if !selection.isSelected(item.id) { selection.selectSingle(item) }
        }
        if event.clickCount == 2 { handleDoubleClick() }
    }

    func handleRightClick(event: NSEvent, view: NSView) {
        ShelfContextMenuHandler.present(event: event, in: view, item: item)
    }

    func handleDoubleClick() {
        let selected = ShelfSelectionModel.shared.selectedItems(in: ShelfStateViewModel.shared.items)
        fileHandler.open(items: selected)
    }
}
