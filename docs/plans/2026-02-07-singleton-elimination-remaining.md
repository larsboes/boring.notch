# Remaining Singleton Elimination Plan

> **For Claude:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate all remaining app-specific `.shared` singletons from the codebase.

**Tech Stack:** Swift 5.9+, SwiftUI, `@Observable` / `@MainActor`, `@Environment` injection.

---

## Current `.shared` Usage (Updated 2026-02-08)

| Singleton | Consumers | Status |
|-----------|-----------|--------|
| `SettingsWindowController.shared` | ~~ContentView, BoringHeader, BoringExtrasMenu~~ | ✅ **Complete** |
| `SharingStateManager.shared` | ~~ContentView, QuickShareService, ServiceContainer, BoringViewModel~~ | ✅ **Complete** |
| `QuickShareService.shared` | ~~boringNotchApp, ShelfSettingsView, FileShareView, ShelfActionService~~ | ✅ **Complete** |
| `NotchSpaceManager.shared` | ~~WindowCoordinator~~ | ✅ **Complete** |

**Dead `.shared` declarations (no external consumers — cleanup only):**

| Singleton | Notes | Status |
|-----------|-------|--------|
| `SoundService.shared` | Removed dead declaration | ✅ **Cleanup done** |
| `OpenWeatherMapService.shared` | Removed dead declaration | ✅ **Cleanup done** |
| `MetalBlurRenderer.shared` | Deleted file (deprecated stub, zero refs) | ✅ **Cleanup done** |
| `LiquidGlassManager.shared` | Deleted file (deprecated stub, zero refs) | ✅ **Cleanup done** |

**Acceptable `.shared` usages (skip):**
- `BoringViewCoordinator.shared` — Root injection points only (boringNotchApp:180, SettingsWindowController:72, BoringViewModel convenience init:180, NotchContentRouter preview:230)
- `NSWorkspace.shared`, `NSApplication.shared`, `URLSession.shared`, `URLCache.shared` — System APIs
- `XPCHelperClient.shared`, `FullScreenMonitor.shared` — External dependencies
- `QLThumbnailGenerator.shared`, `QLPreviewPanel.shared()`, `NSScreenUUIDCache.shared` — System/utility singletons
- `SkyLightOperator.shared` — External package (`SkyLightWindow`)
- `DefaultsNotchSettings.shared` — Settings injection point (boringNotchApp, SettingsWindowController, NotchSettings default)

---

## Task 1: SettingsWindowController ✅ COMPLETE

**Implementation:** Created `SettingsOpener.swift` with `showSettingsWindow` environment key. All consumers migrated to use `@Environment(\.showSettingsWindow)`.

---

## Task 2: SharingStateManager ✅ COMPLETE

**Implementation:** Removed `static let shared`. ServiceContainer creates and owns the instance. ContentView accesses via `pluginManager!.services.sharing`. QuickShareService accepts `SharingServiceProtocol` via init. BoringViewModel `preventClose` closure wired through boringNotchApp from `services.sharing.preventNotchClose`.

---

## Task 3: QuickShareService ✅ COMPLETE

**Implementation:** Removed `static let shared` and `QuickShareProvider.defaultProvider` static property. ServiceContainer owns the instance via `quickShare` property. Views (`ShelfSettingsView`, `FileShareView`) access via `pluginManager!.services.quickShare`. `ShelfActionService` and `ShelfItemViewModel` accept `quickShareService` parameter through the call chain.

---

## Task 4: NotchSpaceManager ✅ COMPLETE

**Implementation:** Removed `static let shared` and `private init()`. `boringNotchApp` creates `NotchSpaceManager()`, passes to `WindowCoordinator` via init. All 4 call sites in WindowCoordinator use `spaceManager.notchSpace` instead of `NotchSpaceManager.shared.notchSpace`. Also fixed pre-existing `appDelegate` scope error in `showOnboardingWindow` → `self`.

---

## Task 5: Dead `.shared` Cleanup ✅ COMPLETE

**Implementation:** Removed `static let shared` from `SoundService` and `OpenWeatherMapService`. Deleted `MetalBlurRenderer.swift` and `LiquidGlassManager.swift` entirely (deprecated stubs with zero external references, confirmed by build). Cleaned all 8 pbxproj references.

---

## Build Verification

After every task:
```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

## Commit Strategy

One commit per task:
- ~~`refactor: eliminate .shared from SettingsWindowController consumers`~~ ✅
- ~~`refactor: eliminate .shared from SharingStateManager`~~ ✅
- ~~`refactor: eliminate .shared from QuickShareService`~~ ✅
- ~~`refactor: eliminate .shared from NotchSpaceManager`~~ ✅
- ~~`refactor: remove dead .shared declarations and deprecated stubs`~~ ✅
