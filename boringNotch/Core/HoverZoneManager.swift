//
//  HoverZoneManager.swift
//  boringNotch
//
//  Single source of truth for hover zone geometry.
//  Uses fixed screen coordinates, decoupled from animated view bounds.
//

import AppKit
import Foundation

/// Manages the hover detection zone using fixed screen coordinates.
/// This ensures hover detection works correctly during open/close animations
/// because the zone doesn't change with the animated view bounds.
@MainActor
final class HoverZoneManager {
    /// The fixed hover zone in screen coordinates
    private(set) var hoverZone: CGRect = .zero

    /// Padding around the notch to extend the hover area
    private let hoverPadding: CGFloat = 20

    /// Current screen UUID for zone calculation
    private var currentScreenUUID: String?

    // MARK: - Public API

    /// Updates the hover zone based on the notch's closed dimensions.
    /// Call this when screen changes, NOT during animations.
    func updateHoverZone(screenUUID: String?) {
        currentScreenUUID = screenUUID
        recalculateZone()
    }

    /// Checks if the mouse is currently within the hover zone.
    /// Uses actual mouse position in screen coordinates.
    func isMouseInHoverZone() -> Bool {
        let mousePos = NSEvent.mouseLocation
        return hoverZone.contains(mousePos)
    }

    /// Forces recalculation of the hover zone.
    /// Call when notch dimensions might have changed (settings, screen change).
    func recalculateZone() {
        guard let screenFrame = getScreenFrame(currentScreenUUID) else {
            hoverZone = .zero
            return
        }

        // Get the closed notch size (the "visible" notch when collapsed)
        let closedSize = getClosedNotchSize(screenUUID: currentScreenUUID)

        // Calculate notch position at top-center of screen
        // Note: macOS screen coordinates have origin at bottom-left
        let notchWidth = closedSize.width
        let notchHeight = closedSize.height

        let x = screenFrame.midX - (notchWidth / 2) - hoverPadding
        let y = screenFrame.maxY - notchHeight - hoverPadding

        // Create hover zone with padding on all sides
        hoverZone = CGRect(
            x: x,
            y: y,
            width: notchWidth + (2 * hoverPadding),
            height: notchHeight + (2 * hoverPadding)
        )
    }
}
