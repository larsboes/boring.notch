# boringNotch — Project Evolution PRD + Implementation Plan

**Goal:** Take boringNotch from "plugin foundation installed, violations remaining" to a clean, extensible notch platform with data portability, automation hooks, and a path to third-party plugins.

**Architecture:** Plugin-first + DI via ServiceContainer + @Observable/@MainActor throughout. Every feature is a plugin. Views never construct services. All cross-plugin communication via PluginEventBus.

**Tech Stack:** Swift 5.9+, SwiftUI/AppKit, Defaults (settings), Combine (publishers), XPC helper, Sparkle (updates), Lottie (animations), KeyboardShortcuts

**Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
**Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`

---

## Current State (updated 2026-02-25 — audited against codebase)

**Active branch:** `refactor/singleton-elimination-tier3`
**Stable branch:** `developer` (always green, same commit as working branch until next merge)

### Phase 1 — Architecture Cleanup Status

| Status | Task | Notes |
|--------|------|-------|
| ✅ | Task 1 — Inline service construction | VolumeManager/BrightnessManager orphans removed from ContentView, OpenNotchHUD, InlineHUD |
| ✅ | Task 2 — ShelfActionService split | Decomposed into ShelfDropService + ShelfMenuActionTarget + ShelfMenuDialogs + QuickShareService (282 lines) |
| ✅ | Task 3 — MusicManager decomposition | MusicManager → thin façade (147L); MusicPlaybackController (294L) + MusicArtworkService (142L) extracted |
| ✅ | Task 4 — ContentView split | ContentView 285L; NotchGestureCoordinator + NotchDropDelegate extracted to Core/ |
| ✅ | Task 5 — boringNotchApp split | AppObjectGraph extracted (242L); boringNotchApp thinned (247L) |
| 🔴 | Task 6 — Defaults access | **62 `Defaults[` violations in 13 files + 2 `@Default` violations** (see below) |
| ✅ | Task 7 — NotchSettings ISP split | 11 focused sub-protocols in NotchSettingsSubProtocols.swift |
| ✅ | Task 8 — BoringViewCoordinator.shared | `.shared` eliminated — **but 24 non-allowed `.shared` singletons remain across 10 custom types** |

**Phase 1 is ≈50% done.** Previous assessment (95%) only counted `@Default` property wrappers, missing the bulk of violations.

### Remaining Violations — `Defaults[` Direct Access (62 violations, 13 files)

Only `DefaultsNotchSettings.swift` (186) and `PluginSettings.swift` (4) are allowed `Defaults[` access.

| File | Count | Category |
|------|-------|----------|
| `BoringViewCoordinator.swift` | 25 | Legacy coordinator — biggest offender |
| `Color+AccentColor.swift` | 8 | Extension |
| `NotificationCenterManager.swift` | 6 | Manager |
| `BatteryService.swift` | 6 | Service (should use NotchSettings) |
| `MusicPlaybackController.swift` | 4 | Manager |
| `MusicArtworkService.swift` | 2 | Manager |
| `ImageService.swift` | 2 | Manager |
| `CalendarService.swift` | 2 | Service |
| `FaceService.swift` | 2 | Service |
| `MediaKeyInterceptor.swift` | 2 | Observer |
| `FullscreenMediaDetection.swift` | 1 | Observer |
| `WeatherService.swift` | 1 | Service |
| `MusicManager.swift` | 1 | Manager |

**Borderline files (need review):**
- `NotchViewModelSettings.swift` (7) — settings helper, may be acceptable
- `sizing/matters.swift` (14) — sizing calculations, may be acceptable

### Remaining Violations — `@Default` Property Wrapper (2 violations)

1. **`boringNotchApp.swift:41`** — `@Default(.menubarIcon)` binding for `MenuBarExtra`. Fix: expose `AppObjectGraph.settings` as concrete `DefaultsNotchSettings` for `@Bindable`.
2. **`LottieAnimationView.swift:12`** — `@Default(.selectedVisualizer)`. Fix: add to `WidgetSettings` sub-protocol, then use `@Environment(\.settings)`.

### Remaining Violations — Non-Allowed `.shared` Singletons (24 usages, 10 types)

System-allowed `.shared` (NSWorkspace, NSApplication, URLSession, URLCache, XPCHelperClient, FullScreenMonitor, QLThumbnailGenerator, QLPreviewPanel, NSScreenUUIDCache, SkyLightOperator, DefaultsNotchSettings) are excluded.

| Singleton | Usages | Files |
|-----------|--------|-------|
| `SettingsWindowController.shared` | 4 | boringNotchApp, BoringHeader, BoringExtrasMenu, SettingsWindowController |
| `NotchSpaceManager.shared` | 4 | WindowCoordinator |
| `SharingStateManager.shared` | 5 | BoringViewModel, QuickShareService, ServiceContainer |
| `ShelfPersistenceService.shared` | 3 | ShelfService |
| `NotificationCenterManager.shared` | 3 | ServiceContainer, NotificationsView, NotificationsSettingsView |
| `QuickShareService.shared` | 2 | ShelfSettingsView, FileShareView |
| `ImageService.shared` | 2 | SpotifyController, YouTubeMusicController |
| `BluetoothManager.shared` | 1 | BluetoothSettingsView (+declaration) |
| `NotesManager.shared` | 2 | NotesView |
| `ClipboardManager.shared` | 1 | ClipboardView |

### Remaining Violations — 300-Line Limit (13 files)

`DefaultsNotchSettings.swift` (412L) is excluded — settings file, splitting would hurt cohesion.

| File | Lines | Priority |
|------|-------|----------|
| `BoringViewModel.swift` | 498 | Critical — god object |
| `BoringCalendar.swift` | 459 | High |
| `NowPlayingController.swift` | 425 | High |
| `VolumeManager.swift` | 380 | Medium |
| `BoringViewCoordinator.swift` | 379 | High (also 25 Defaults violations) |
| `MusicSlotConfigurationView.swift` | 370 | Medium |
| `PluginManager.swift` | 350 | Medium |
| `PluginMusicPlayerView.swift` | 336 | Medium |
| `AdvancedSettingsView.swift` | 329 | Low |
| `WindowCoordinator.swift` | 318 | Medium |
| `WebcamManager.swift` | 312 | Low |
| `LyricsService.swift` | 310 | Low |
| `Constants.swift` | 308 | Low |

### State Management
`NotchHoverController` exists in `models/` with `HoverZoneChecking` DI and unit tests. Current implementation is task/async based. Phase 2 (Task 9) upgrades to heartbeat-based truth polling to eliminate ~15 edge cases.

---

## Vision

**boringNotch = The notch, transformed into a personal command center.**

Three layers of value:
1. **Core experience** — Beautiful, reliable, snappy notch interactions. Correct state machine. No flicker, no stuck-open.
2. **Plugin platform** — All features are plugins. Data is yours (export any format). APIs are open (local REST + WebSocket).
3. **Ecosystem** — Third-party plugins via `.boringplugin` bundles. Raycast/Shortcuts/URL scheme integrations. Optional AI features (local-first).

---

## Implementation Phases

---

## Phase 1 — Architecture Cleanup (Current Sprint)

**Goal:** Zero architecture violations. Every file follows the rules. Build stays green. Tests pass.

**Order matters** — work top-to-bottom to avoid cascading breaks.

---

### Task 1: Fix Inline Service Construction Runtime Bug ✅ COMPLETE

**Implementation (2026-02-24):** `VolumeManager(eventBus: PluginEventBus())` and `BrightnessManager(eventBus: PluginEventBus())` were found in `ContentView`, `OpenNotchHUD`, and `InlineHUD` — not in `NotchContentRouter` as originally documented. All three files updated to use `@Environment(\.pluginManager)` and call `pluginManager?.services.volume/.brightness` instead. Dead declarations in `ContentView` removed. Build verified green.

---

### Task 2: Split `ShelfActionService.swift` ✅ COMPLETE

**Implementation:** 849-line god class decomposed into: `ShelfActionService` (282L, core item actions), `ShelfDropService` (drop handling), `ShelfMenuActionTarget` (menu dispatch), `ShelfMenuDialogs` + `QuickShareService` (share). All files under 300 lines.

Also fixed during audit (2026-02-24): `ShelfItemView.swift` (363L → 137L) by extracting `DraggableClickHandler` + `DraggableClickView` into `ShelfDraggableClickHandler.swift`. `ImageProcessingService.swift` (322L → 262L) by extracting `ImageConversionOptions` + `ImageProcessingError` into `ImageProcessingModels.swift`.

---

### Task 3: Decompose `MusicManager.swift` ✅ COMPLETE

**Implementation:** 672-line god class split into: `MusicManager` thin façade (147L), `MusicPlaybackController` transport (294L), `MusicArtworkService` artwork + color averaging (142L). All under 300 lines.

---

### Task 4: Split `ContentView.swift` ✅ COMPLETE

**Implementation:** ContentView 285L (down from 543L). `NotchGestureCoordinator.swift` and `NotchDropDelegate.swift` extracted to `Core/`.

---

### Task 5: Split `boringNotchApp.swift` ✅ COMPLETE

**Implementation:** `AppObjectGraph.swift` (242L) created as DI root — constructs all services, wires plugins, sets up event bus. `boringNotchApp.swift` thinned to 247L (lifecycle + App shell only).

---

### Task 6: Fix Direct `Defaults[.]` Access 🔴 MOSTLY OPEN

**Previous assessment was wrong.** Only `@Default` property wrappers (2 violations) were counted. The bulk of violations are direct `Defaults[` key access — **62 violations across 13 files.**

#### Task 6a: `@Default` Property Wrapper Violations (2 remaining)

1. **`boringNotchApp.swift:41`** — `@Default(.menubarIcon)` binding for `MenuBarExtra`. Fix: expose `AppObjectGraph.settings` as concrete `DefaultsNotchSettings` for `@Bindable`.
2. **`LottieAnimationView.swift:12`** — `@Default(.selectedVisualizer)`. Fix: add to `WidgetSettings` sub-protocol, then use `@Environment(\.settings)`.

#### Task 6b: `Defaults[` Direct Access Violations (62 remaining, 13 files) 🔴 NEW

Every `Defaults[.key]` outside `DefaultsNotchSettings.swift` and `PluginSettings.swift` must be routed through `NotchSettings` sub-protocols or `PluginSettings`.

**Strategy:** Work tier-by-tier. Services first (they already receive settings), then managers, then observers/extensions.

| Tier | File | Count | Fix Approach |
|------|------|-------|--------------|
| **Services** | `BatteryService.swift` | 6 | Already has settings injection — use it |
| | `CalendarService.swift` | 2 | Already has settings injection — use it |
| | `WeatherService.swift` | 1 | Already has settings injection — use it |
| | `FaceService.swift` | 2 | Add settings injection |
| **Managers** | `BoringViewCoordinator.swift` | 25 | Largest offender — inject settings via init |
| | `NotificationCenterManager.swift` | 6 | Inject settings via init |
| | `MusicPlaybackController.swift` | 4 | Inject settings via init |
| | `MusicArtworkService.swift` | 2 | Inject settings via init |
| | `ImageService.swift` | 2 | Inject settings via init |
| | `MusicManager.swift` | 1 | Inject settings via init |
| **Observers** | `MediaKeyInterceptor.swift` | 2 | Inject settings via init |
| | `FullscreenMediaDetection.swift` | 1 | Inject settings via init |
| **Extensions** | `Color+AccentColor.swift` | 8 | Convert to methods that take settings as parameter |

**Borderline (review needed):**
- `NotchViewModelSettings.swift` (7) — settings helper, may be acceptable as extension of settings layer
- `sizing/matters.swift` (14) — sizing calculations using Defaults directly, should be migrated

---

### Task 7: Split `NotchSettings` Protocol (ISP) ✅ COMPLETE

**Implementation:** `NotchSettings` now composes 11 focused sub-protocols defined in `NotchSettingsSubProtocols.swift` (171L): `HUDSettings`, `BatterySettings`, `AppearanceSettings`, `MediaSettings`, `GestureSettings`, `ShelfSettings`, `DisplaySettings`, `WidgetSettings`, `NotchCalendarSettings`, `NotificationSettings`, `BluetoothSettings`. Both `DefaultsNotchSettings` and `MockNotchSettings` conform.

---

### Task 8: Eliminate Non-Allowed `.shared` Singletons 🔴 MOSTLY OPEN

**Previous assessment was misleading.** `BoringViewCoordinator.shared` was eliminated (Task 8 original scope), but **24 usages of 10 other non-allowed `.shared` singletons remain.**

Allowed `.shared` per CLAUDE.md: NSWorkspace, NSApplication, URLSession, URLCache, XPCHelperClient, FullScreenMonitor, QLThumbnailGenerator, QLPreviewPanel, NSScreenUUIDCache, SkyLightOperator, DefaultsNotchSettings.

| Singleton | Usages | Fix Approach |
|-----------|--------|--------------|
| `SettingsWindowController.shared` | 4 | Inject via `AppObjectGraph` or `@Environment` |
| `NotchSpaceManager.shared` | 4 | Inject into `WindowCoordinator` via init |
| `SharingStateManager.shared` | 5 | Already in `ServiceContainer` — use DI path |
| `ShelfPersistenceService.shared` | 3 | Inject into `ShelfService` via init |
| `NotificationCenterManager.shared` | 3 | Already in `ServiceContainer` — use DI path |
| `QuickShareService.shared` | 2 | Inject via `ServiceContainer` |
| `ImageService.shared` | 2 | Inject into MediaControllers via init |
| `BluetoothManager.shared` | 1+decl | Inject via `ServiceContainer` |
| `NotesManager.shared` | 2 | Inject via `@Environment` |
| `ClipboardManager.shared` | 1 | Inject via `@Environment` |

---

### Task 8c: Split Files Exceeding 300-Line Limit 🔴 NEW

13 files exceed the 300-line hard limit. `DefaultsNotchSettings.swift` (412L) is excluded — splitting would hurt settings cohesion.

| File | Lines | Split Strategy |
|------|-------|----------------|
| `BoringViewModel.swift` | 498 | Extract notification handling, shelf logic, gesture handling into separate files |
| `BoringCalendar.swift` | 459 | Extract subviews (day cell, event row, month header) |
| `NowPlayingController.swift` | 425 | Extract per-app controller logic |
| `VolumeManager.swift` | 380 | Extract OSD/HUD display logic |
| `BoringViewCoordinator.swift` | 379 | Extract settings-dependent logic (also 25 Defaults violations) |
| `MusicSlotConfigurationView.swift` | 370 | Extract slot editor subviews |
| `PluginManager.swift` | 350 | Extract lifecycle management |
| `PluginMusicPlayerView.swift` | 336 | Extract subviews (artwork, controls, lyrics) |
| `AdvancedSettingsView.swift` | 329 | Extract setting sections |
| `WindowCoordinator.swift` | 318 | Extract window creation logic |
| `WebcamManager.swift` | 312 | Extract capture session setup |
| `LyricsService.swift` | 310 | Extract lyrics parsing |
| `Constants.swift` | 308 | Split by domain (UI constants, timing constants, etc.) |

---

## Phase 2 — State Management Overhaul

**Goal:** Replace event-driven hover with heartbeat-based truth polling.

**Why:** SwiftUI layout shifts cause `NSTrackingArea` to recalculate bounds, firing spurious `mouseExit` even when the mouse never moved. The current system treats these as real exits → ~15 edge cases. The fix: stop trusting events, check `NSEvent.mouseLocation` directly.

**Design principle:** `NSEvent.mouseLocation` cannot lie. `window.frame` is stable during layout shifts. Checking truth every 16ms catches everything — events become latency optimisations, not requirements.

---

### Task 9: Upgrade `NotchHoverController` to Heartbeat Architecture

**Note:** `NotchHoverController` already exists in `models/` with `HoverZoneChecking` DI and unit tests. This task upgrades its internal mechanism from async-task debouncing to a heartbeat state machine.

**Files:**
- Modify: `boringNotch/models/NotchHoverController.swift`
- Modify: `boringNotch/models/BoringViewModel.swift`
- Modify: `boringNotchTests/NotchHoverControllerTests.swift`

**State machine — 4 states:**

```swift
enum HoverState: Equatable {
    case outside
    case entering(since: Date)   // debounce window
    case inside
    case exiting(since: Date)    // close delay window
}
```

**Timing constants:**
- `enterDelay = 50ms` — prevents open on quick pass-through
- `exitDelayNormal = 500ms` — standard close delay
- `exitDelayShelf = 4s` — gives time to drag files back in

**`tick()` — core logic (called by heartbeat every 16ms):**

```swift
func tick() {
    let isInside = hoverZoneManager.isMouseInHoverZone()
    let now = Date()
    switch state {
    case .outside:
        if isInside { state = .entering(since: now) }
    case .entering(let since):
        if !isInside { state = .outside }
        else if now.timeIntervalSince(since) >= enterDelay {
            state = .inside; onShouldOpen?()
        }
    case .inside:
        if !isInside { state = .exiting(since: now) }
    case .exiting(let since):
        if isInside { state = .inside }  // cancel close
        else if now.timeIntervalSince(since) >= (isShelfActive ? exitDelayShelf : exitDelayNormal) {
            state = .outside; onShouldClose?()
        }
    }
}
```

**Heartbeat — only runs when notch is open (negligible CPU: ~0.12ms/s):**

```swift
func startHeartbeat() {
    guard heartbeat == nil else { return }
    heartbeat = Task { [weak self] in
        while !Task.isCancelled {
            self?.tick()
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
func stopHeartbeat() { heartbeat?.cancel(); heartbeat = nil }
```

**`TrackingAreaView` becomes a hint only** — call `tick()` immediately on `mouseEntered`/`mouseExited` for low latency, but never set state directly from events.

**Step 1: Refactor `NotchHoverController`**

Replace the current open/close `Task` approach with the state machine + heartbeat above. Keep `HoverZoneChecking` injection (already in place). Expose `state: HoverState` and `isShelfActive: Bool`.

**Step 2: Update `BoringViewModel` integration**

```swift
// start heartbeat when notch opens, stop when it closes
func open() { /* ... */ hoverController.startHeartbeat() }
func close(force: Bool) { /* ... */ hoverController.stopHeartbeat() }

// shelf mode: longer exit delay
func showShelf() { hoverController.isShelfActive = true }
func hideShelf() { hoverController.isShelfActive = false }
```

**Step 3: Update tests**

Update `NotchHoverControllerTests` to use `tick()` directly (no `simulateMouseInside` needed — `MockHoverZoneChecker.mouseInZone` drives state). Cover:
- Quick pass-through → no open
- 50ms+ dwell → opens
- Exit + re-enter within delay → close cancelled
- Shelf mode: exit + re-enter within 4s → close cancelled

**Step 4: Build + test**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50
```

**Step 5: Manual verification checklist**

- [ ] Normal hover → open → close works
- [ ] Quick pass-through does NOT open
- [ ] Button click inside open notch does NOT trigger close
- [ ] Mouse leaving + returning within delay cancels close
- [ ] File drag with shelf open: 4s delay respected
- [ ] Multi-screen: each window's heartbeat is independent
- [ ] Second screen hover works independently

**Step 8: Commit**

```bash
git add boringNotch/Core/NotchHoverController.swift boringNotch/models/BoringViewModel.swift boringNotchTests/
git commit -m "feat: replace event-driven hover with heartbeat-based NotchHoverController"
```

---

## Phase 3 — Data Portability Layer

**Goal:** Every plugin can export its data in standard formats. Users own their data.

**Why it matters:** Differentiator. Reinforces "no vendor lock-in" principle. Needed before adding Habit Tracker, Pomodoro (data-heavy plugins).

---

### Task 10: `ExportablePlugin` Protocol + Export Infrastructure

**Files:**
- Modify: `boringNotch/Plugins/Core/PluginCapabilities.swift`
- Create: `boringNotch/Plugins/Core/ExportTypes.swift`
- Create: `boringNotch/Plugins/Services/ExportCoordinator.swift`

**Acceptance criteria:**
- `ExportablePlugin` protocol defined with `supportedExportFormats: [ExportFormat]` and `exportData(format:) async throws -> Data`
- `ExportFormat` enum: `.json`, `.csv`, `.markdown`, `.ical`, `.html`
- `ExportCoordinator` in `ServiceContainer` that calls `plugin.exportData(format:)` and saves to temp file + presents save panel
- `MusicPlugin` adopts `ExportablePlugin` (exports listening history as JSON/CSV)
- `CalendarPlugin` adopts `ExportablePlugin` (exports events as iCal/JSON)
- `ShelfPlugin` adopts `ExportablePlugin` (exports item metadata as JSON/CSV)

**Test:** Write `ExportCoordinatorTests` using `MockExportablePlugin` that returns canned data.

---

### Task 11: Export UI in Settings

**Files:**
- Modify: `boringNotch/components/Settings/Views/AdvancedSettingsView.swift` or new file
- Create: `boringNotch/components/Settings/Views/DataPortabilityView.swift`

**Acceptance criteria:**
- Settings section "Data & Privacy" with list of all exportable plugins
- Per-plugin: format picker + "Export" button
- "Export All" button at bottom
- Save panel (NSSavePanel) presented after export
- Under 200 lines

---

## Phase 4 — New Built-In Plugins

**Goal:** Ship 2 high-value new plugins (Habit Tracker + Pomodoro) to validate the plugin API is first-class and exportable.

**Prerequisite:** Phase 3 complete (ExportablePlugin protocol in place).

---

### Task 12: `HabitTrackerPlugin`

**Directory:** `boringNotch/Plugins/BuiltIn/HabitTrackerPlugin/`

**Files to create:**
- `HabitTrackerPlugin.swift` — plugin class
- `HabitModels.swift` — `Habit`, `HabitCompletion`, `HabitStreak` structs (all `Codable & Sendable`)
- `HabitStore.swift` — persistence using `PluginSettings` + JSON file in Application Support
- `Views/HabitClosedView.swift` — today's habits as dots (≤100 lines)
- `Views/HabitExpandedView.swift` — full habit list with check buttons (≤200 lines)
- `Views/HabitSettingsView.swift` — reminder times, export options (≤150 lines)

**Acceptance criteria:**
- Conforms to `NotchPlugin` + `ExportablePlugin` (JSON + CSV export)
- Closed notch: dots for today's habits (filled = done, hollow = pending)
- Expanded: habit list, tap to complete, streak counter
- Settings: add/edit/archive habits, reminder time
- Data stored in `~/Library/Application Support/boringNotch/habits.json`
- `displayRequest` priority `.background` normally, `.normal` if any habit due in next hour

**Tests:** `HabitStoreTests`, `HabitPluginTests` using mock context.

---

### Task 13: `PomodoroPlugin`

**Directory:** `boringNotch/Plugins/BuiltIn/PomodoroPlugin/`

**Files to create:**
- `PomodoroPlugin.swift`
- `PomodoroTimer.swift` — pure timer logic (no SwiftUI), `@Observable @MainActor`
- `PomodoroModels.swift` — `PomodoroSession`, `PomodoroSettings`, `SessionType` enum
- `Views/PomodoroClosedView.swift` — countdown ring in closed notch
- `Views/PomodoroExpandedView.swift` — timer + session type + controls
- `Views/PomodoroSettingsView.swift`

**Acceptance criteria:**
- Conforms to `NotchPlugin` + `ExportablePlugin` (CSV compatible with Toggl/Clockify import)
- Closed notch: circular progress ring showing remaining time, color-coded by session type
- Expanded: start/pause/skip, work/break labels, session count
- `displayRequest` priority `.high` when timer running, `nil` when idle
- Publishes `SneakPeekRequestedEvent` when session completes (shows HUD notification)
- Optional macOS Focus mode integration during work sessions

**Tests:** `PomodoroTimerTests` (pure unit test, no XCTest UI).

---

## Phase 5 — Automation & Integrations

**Goal:** Make boringNotch controllable from outside the app. Power users, Raycast, Shortcuts, scripts.

---

### Task 14: App Intents (Shortcuts)

**Files:**
- Create: `boringNotch/Shortcuts/AppIntents.swift`

**Intents to implement:**
```swift
// OpenNotchIntent — opens to specific tab
// CloseNotchIntent
// StartPomodoroIntent — starts a Pomodoro session
// CompleteHabitIntent(habitId:) — marks habit done
// AddToShelfIntent(url:) — adds URL or file to shelf
// ExportDataIntent(pluginId:, format:) — exports plugin data
```

**Acceptance criteria:**
- All intents visible in Shortcuts.app
- Each intent has a proper `description` and parameter documentation
- Intents call into `PluginManager` via app extension — no direct singleton access

---

### Task 15: URL Scheme Handler

**Files:**
- Modify: `boringNotch/boringNotchApp.swift` (or `AppDelegate`)
- Create: `boringNotch/Core/URLSchemeHandler.swift`

**URL scheme:** `boringnotch://`

**Routes to implement:**
```
boringnotch://open                   → open notch
boringnotch://open?tab=calendar      → open to tab
boringnotch://close                  → close notch
boringnotch://shelf/add?url=...      → add URL to shelf
boringnotch://plugin/pomodoro/start  → start Pomodoro
boringnotch://plugin/habits/complete?id=...  → complete habit
boringnotch://export?plugin=all&format=json  → export data
```

**Acceptance criteria:**
- `URLSchemeHandler` is a dedicated type, not inline in AppDelegate
- Each route delegates to `PluginManager` or `WindowCoordinator` — no direct manager access
- Unknown routes log a warning, don't crash
- Registered in `Info.plist`

---

## Phase 6 — Local API Server

**Goal:** REST + WebSocket API at `localhost:19384`. Enables Raycast extension, browser extension, CLI, and any scripting integration.

**This phase is design-heavy — do a brainstorm session first (`superpowers:brainstorming`) before implementation.**

---

### Task 16: Local REST API + WebSocket

**Files:**
- Create: `boringNotch/LocalAPI/` directory
  - `LocalAPIServer.swift` — HTTP server (use `Network.framework` or embed `Swifter`/`Vapor` as dependency)
  - `APIRoutes.swift` — route definitions
  - `APIModels.swift` — Codable request/response types
  - `WebSocketEventStream.swift` — real-time event push

**Endpoints (MVP):**
```
GET  /api/v1/plugins              → list active plugins + state
GET  /api/v1/plugins/{id}/data    → get plugin's exported data (JSON)
POST /api/v1/plugins/{id}/action  → trigger plugin action (start, complete, etc.)
GET  /api/v1/notch/state          → current notch state
POST /api/v1/notch/open           → open notch
POST /api/v1/notch/close          → close notch
GET  /api/v1/music/now-playing    → current track info
WS   /api/v1/events               → real-time event stream
```

**Security:** Bind to `127.0.0.1` only (no remote access by default). Optional token auth for future remote use.

**Acceptance criteria:**
- Server starts/stops with app lifecycle
- `pluginManager!.services` is the only dependency
- No singleton access in route handlers
- Events from `PluginEventBus` forwarded to WebSocket clients
- Documented in `docs/LOCAL_API.md`

---

## Phase 7 — Third-Party Plugin Distribution

**Goal:** `.boringplugin` bundle format + plugin discovery UI. This enables the ecosystem.

**This phase requires separate design work. Create a dedicated plan document when Phase 6 is complete.**

High-level requirements:
- `.boringplugin` = signed Swift package bundle
- Plugin manifest declaring permissions, required services, compatible versions
- Permission approval UI (like app permissions on macOS)
- Plugin browser in Settings → "Discover Plugins"
- GitHub topics (`#boringnotch-plugin`) for discovery
- Local folder: `~/Library/Application Support/boringNotch/Plugins/`

---

## Success Metrics Per Phase

| Phase | Done When |
|-------|-----------|
| 1 | Zero `Defaults[` outside `DefaultsNotchSettings.swift`/`PluginSettings.swift`. Zero `@Default` outside `DefaultsNotchSettings.swift`. Zero non-allowed `.shared`. Zero files > 300 lines (except `DefaultsNotchSettings.swift`). Build green, tests pass. **Remaining: 62 Defaults[ + 2 @Default + 24 .shared + 13 oversized files.** |
| 2 | Hover is heartbeat-based. `NotchHoverController` has unit tests. 6 manual edge cases verified. |
| 3 | `ExportablePlugin` protocol exists. Music, Calendar, Shelf export. Export UI in Settings. |
| 4 | HabitTracker + Pomodoro shipped. Both export. Both have unit tests. |
| 5 | All 6 App Intents visible in Shortcuts. URL scheme routes all work. |
| 6 | Local API responds on `localhost:19384`. WebSocket stream works. Raycast integration demonstrated. |
| 7 | One external plugin loads from `~/Library/Application Support/boringNotch/Plugins/`. |

---

## Key Constraints

- **300-line hard limit per file** — no exceptions added during this plan
- **No new singletons** — `AppObjectGraph` is the only DI root
- **Protocol before implementation** — new services get a protocol file first
- **Build must stay green** — no broken intermediate states committed
- **One commit per logical unit** — enables rollback without losing adjacent work
- **Tests before ship** — every new plugin and coordinator gets unit tests

---

## Files to Not Touch

- `boringNotch/Plugins/Core/NotchPlugin.swift` — stable protocol, only extend via `PluginCapabilities.swift`
- `boringNotch/Plugins/Core/PluginEventBus.swift` — stable, new event types added as new structs
- `boringNotch/Core/NotchStateMachine.swift` — pure, tested, stable. Modify only if state machine logic changes.
- `boringNotch/private/CGSSpace.swift` — private API wrapper, don't touch
- `mediaremote-adapter/` — pre-built framework, read-only
