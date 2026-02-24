//
//  ScreenSelectionService.swift
//  boringNotch
//
//  Extracted from BoringViewCoordinator — owns screen selection state and migration.
//

import AppKit
import Combine
// Required for Defaults.updates() reactive stream observers
import Defaults

/// Manages which screen the notch is displayed on.
///
/// Responsibilities:
/// - One-time migration from legacy name-based → UUID-based storage
/// - Runtime `selectedScreenUUID` (set by WindowCoordinator during layout)
/// - Persisted `preferredScreenUUID` (user's preference)
/// - Observer that posts `.selectedScreenChanged` when preference changes
@MainActor
@Observable
final class ScreenSelectionService {
    // MARK: - State

    /// Runtime-only: the screen we're currently showing on (not persisted)
    var selectedScreenUUID: String

    /// Persisted user preference (delegates to NotchSettings)
    var preferredScreenUUID: String? {
        get { settings.preferredScreenUUID }
        set { settings.preferredScreenUUID = newValue }
    }

    // MARK: - Private

    private var settings: NotchSettings
    nonisolated(unsafe) private var preferredScreenObserverTask: Task<Void, Never>?

    // MARK: - Init

    init(settings: NotchSettings) {
        self.settings = settings

        // Run one-time migration before anything else
        let migratedUUID = Self.migrateIfNeeded(settings: settings)
        self.selectedScreenUUID = migratedUUID ?? settings.preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""

        // Watch for preference changes → update runtime state + notify
        preferredScreenObserverTask = Task { @MainActor [weak self] in
            for await uuid in Defaults.updates(.preferredScreenUUID) {
                guard let self else { return }
                if let uuid {
                    self.selectedScreenUUID = uuid
                }
                NotificationCenter.default.post(name: .selectedScreenChanged, object: nil)
            }
        }
    }

    deinit {
        preferredScreenObserverTask?.cancel()
    }

    // MARK: - Migration

    /// Migrates legacy name-based screen preference to UUID-based.
    /// Returns the resolved UUID or nil.
    private static func migrateIfNeeded(settings: NotchSettings) -> String? {
        let legacyName = UserDefaults.standard.string(forKey: "preferred_screen_name")
        var resolvedUUID = settings.preferredScreenUUID
        // Use a mutable copy for writes during migration
        var mutableSettings = settings

        if resolvedUUID == nil, let legacyName {
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                mutableSettings.preferredScreenUUID = uuid
                resolvedUUID = uuid
                NSLog("Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                let mainUUID = NSScreen.main?.displayUUID
                mutableSettings.preferredScreenUUID = mainUUID
                resolvedUUID = mainUUID
                NSLog("Could not find display named '\(legacyName)', falling back to main screen")
            }
            UserDefaults.standard.removeObject(forKey: "preferred_screen_name")
        } else if resolvedUUID == nil {
            let mainUUID = NSScreen.main?.displayUUID
            mutableSettings.preferredScreenUUID = mainUUID
            resolvedUUID = mainUUID
        }

        return resolvedUUID
    }
}
