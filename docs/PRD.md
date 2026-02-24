# boringNotch — Project Evolution PRD + Implementation Plan

**Goal:** Take boringNotch from "plugin foundation installed, violations remaining" to a clean, extensible notch platform with data portability, automation hooks, and a path to third-party plugins.

**Architecture:** Plugin-first + DI via ServiceContainer + @Observable/@MainActor throughout. Every feature is a plugin. Views never construct services. All cross-plugin communication via PluginEventBus.

**Tech Stack:** Swift 5.9+, SwiftUI/AppKit, Defaults (settings), Combine (publishers), XPC helper, Sparkle (updates), Lottie (animations), KeyboardShortcuts

**Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
**Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`

---

## Current State (updated 2026-02-24)

**Active branch:** `refactor/singleton-elimination-tier3` (off `refactor/full-refactor`)

### What's Done
- Plugin system: `PluginManager`, `NotchPlugin` protocol, `ServiceContainer`, `PluginEventBus`, 8 built-in plugins
- `NotchStateMachine` — pure, fully testable, no SwiftUI/AppKit imports
- `WindowCoordinator` — extracted from AppDelegate
- Settings: `NotchSettings` protocol + `DefaultsNotchSettings` + `MockNotchSettings` + dual env keys
- Singleton elimination: `SettingsWindowController`, `SharingStateManager`, `QuickShareService`, `NotchSpaceManager` — all done (see `2026-02-07-singleton-elimination-remaining.md`)
- Protocol-based services for all 8 built-in domains
- App launches without crashes — `BoringViewCoordinator` and `NotchStateMachine` now correctly injected into window environment
- **Task 1 complete:** Orphaned `VolumeManager`/`BrightnessManager` with throwaway `PluginEventBus()` removed from `ContentView`, `OpenNotchHUD`, `InlineHUD` — now use `pluginManager.services.volume/.brightness`
- `HoverZoneChecking` protocol extracted — `NotchHoverController` testable via DI
- `NotchHoverControllerTests` rewritten against real API with `MockHoverZoneChecker`

### What Remains — Violations Blocking Clean Architecture

| Priority | Task | File | Problem |
|----------|------|------|---------|
| ✅ | Task 1 | `ContentView`, `OpenNotchHUD`, `InlineHUD` | ~~Inline `VolumeManager`/`BrightnessManager` with orphaned event buses~~ — **DONE** |
| 🔴 | Task 2 | `components/Shelf/Services/ShelfActionService.swift` | 849 lines — god class needing 3-way split |
| 🔴 | Task 3 | `managers/MusicManager.swift` | 672 lines — not properly behind `MusicServiceProtocol` |
| 🟡 | Task 4 | `ContentView.swift` | ~530 lines — gestures + animation + drop delegate + state obs mixed |
| 🟡 | Task 5 | `boringNotchApp.swift` | ~248 lines — still has lifecycle + some graph wiring mixed |
| 🟡 | Task 6 | `components/Calendar/BoringCalendar.swift` | 459 lines — view + formatting logic mixed |
| 🟡 | Task 8 | `BoringViewCoordinator.swift` | 4 remaining `.shared` access points to wire via DI |
| 🟢 | Task 6 | Several settings views | Direct `Defaults[.]` access instead of `@Environment(\.bindableSettings)` |
| 🟢 | Task 7 | `NotchSettings` protocol | 50+ properties — ISP violation, needs splitting into focused sub-protocols |

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

### Task 2: Split `ShelfActionService.swift` (849 lines → 3 files)

**Files:**
- Modify: `boringNotch/components/Shelf/Services/ShelfActionService.swift`
- Create: `boringNotch/components/Shelf/Services/ShelfDragDropHandler.swift`
- Create: `boringNotch/components/Shelf/Services/ShelfShareHandler.swift`

**Step 1: Map responsibilities**

Read the file and tag each method/section with one of three labels:
- **CORE** — core item management (add, remove, reorder, persistence)
- **DRAGDROP** — drag-and-drop receive, UTType handling, NSItemProvider loading
- **SHARE** — QuickShare, AirDrop, copy, export actions

**Step 2: Create `ShelfDragDropHandler.swift`**

Extract all `DRAGDROP` logic into a new `@Observable @MainActor final class ShelfDragDropHandler`. It receives `ShelfServiceProtocol` via init injection.

```swift
@Observable
@MainActor
final class ShelfDragDropHandler {
    private let shelfService: ShelfServiceProtocol

    init(shelfService: ShelfServiceProtocol) {
        self.shelfService = shelfService
    }

    // all drag-drop methods here
}
```

**Step 3: Create `ShelfShareHandler.swift`**

Extract all `SHARE` logic into a new `@Observable @MainActor final class ShelfShareHandler`. Receives `QuickShareService` via init.

**Step 4: Update `ShelfActionService.swift`**

Remove extracted code. Keep only CORE logic. Should be under 250 lines. Update callers (`ShelfPlugin`, `ShelfItemViewModel`, any views) to use the appropriate handler.

**Step 5: Add to Xcode project**

```bash
# Check pbxproj has new files — if using script:
.agent/workflows/manage-xcode-files.md
```

**Step 6: Build**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

**Step 7: Commit**

```bash
git add boringNotch/components/Shelf/Services/
git commit -m "refactor: split ShelfActionService into action/dragdrop/share handlers"
```

---

### Task 3: Decompose `MusicManager.swift` (672 lines)

**Files:**
- Modify: `boringNotch/managers/MusicManager.swift`
- Modify: `boringNotch/Plugins/Services/MusicService.swift`
- Create: `boringNotch/managers/MusicPlaybackController.swift`
- Create: `boringNotch/managers/MusicArtworkService.swift`

**Step 1: Identify three sub-responsibilities in MusicManager**

- **TRANSPORT** — play/pause/next/prev/seek, controller selection (Apple Music, Spotify, YouTube Music, NowPlaying)
- **ARTWORK** — album art fetching, averaging color computation
- **LYRICS** — lyrics fetching and display state (may already be in `LyricsService`)

**Step 2: Extract `MusicPlaybackController.swift`**

Move TRANSPORT logic here. This is the main active class — receives `MediaControllerProtocol` instances via init.

**Step 3: Extract `MusicArtworkService.swift`**

Move artwork fetching + color averaging here. Exposes `artwork: NSImage?` and `avgColor: Color?` as `@Observable` properties.

**Step 4: Thin `MusicManager` or eliminate it**

After extraction, `MusicManager` should either be:
- A thin façade delegating to sub-services (wraps under `MusicServiceProtocol`)
- Completely eliminated, with `MusicService.swift` referencing the two new classes directly

**Step 5: Ensure `MusicPlugin` accesses music only via `MusicServiceProtocol`**

`context.services.music` must satisfy `MusicPlugin`'s needs. If the protocol is missing methods that MusicPlugin calls, add them to the protocol first, then implement.

**Step 6: Build + test**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50
```

**Step 7: Commit**

```bash
git add boringNotch/managers/ boringNotch/Plugins/Services/MusicService.swift
git commit -m "refactor: decompose MusicManager into transport/artwork sub-services"
```

---

### Task 4: Split `ContentView.swift` (543 lines)

**Files:**
- Modify: `boringNotch/ContentView.swift`
- Create: `boringNotch/Core/NotchGestureCoordinator.swift`
- Create: `boringNotch/Core/NotchDropDelegate.swift`

**Step 1: Extract drop delegate**

All `NSItemProviderReading`, `DropDelegate`, `onDrop` handling → `NotchDropDelegate.swift`. This is a pure data type with no SwiftUI view code.

```swift
@MainActor
struct NotchDropDelegate: DropDelegate {
    let shelfService: ShelfServiceProtocol
    // ...
}
```

**Step 2: Extract gesture logic**

Pan gesture calculations, velocity thresholds, open/close trigger logic → `NotchGestureCoordinator.swift`. This is a method group, not a type — implement as an extension on the view model or as a separate coordinator.

**Step 3: ContentView stays**

After extraction, `ContentView.swift` should contain only:
- Environment wiring
- Layout structure
- Animation interpolation (corner radii, size)
- `.gesture()` modifier (calling into `NotchGestureCoordinator`)
- `.onDrop()` modifier (using `NotchDropDelegate`)

Target: under 250 lines.

**Step 4: Build**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

**Step 5: Commit**

```bash
git add boringNotch/ContentView.swift boringNotch/Core/
git commit -m "refactor: extract gesture coordinator and drop delegate from ContentView"
```

---

### Task 5: Split `boringNotchApp.swift` (502 lines)

**Files:**
- Modify: `boringNotch/boringNotchApp.swift`
- Create: `boringNotch/AppObjectGraph.swift`

**Step 1: Extract DI graph construction**

Everything that constructs `ServiceContainer`, `PluginManager`, wires plugins, sets up event bus subscriptions → `AppObjectGraph.swift`.

```swift
@MainActor
final class AppObjectGraph {
    let pluginManager: PluginManager
    let windowCoordinator: WindowCoordinator
    let keyboardCoordinator: KeyboardShortcutCoordinator
    let dragCoordinator: DragDetectionCoordinator

    init() {
        let eventBus = PluginEventBus()
        let settings = DefaultsNotchSettings.shared
        let services = ServiceContainer(eventBus: eventBus)
        // ... full wiring here
    }
}
```

**Step 2: `boringNotchApp.swift` becomes a thin shell**

```swift
@main
struct DynamicNotchApp: App {
    @State private var graph = AppObjectGraph()
    // ...
}
```

**Step 3: AppDelegate stays in boringNotchApp.swift but slims down**

AppDelegate handles only: `applicationDidFinishLaunching`, `applicationWillTerminate`, sparkle delegate. Everything else moved out.

**Step 4: Build**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

**Step 5: Commit**

```bash
git add boringNotch/boringNotchApp.swift boringNotch/AppObjectGraph.swift
git commit -m "refactor: extract DI graph construction into AppObjectGraph"
```

---

### Task 6: Fix Remaining Direct `Defaults[.]` Access

**Files to scan:**

```bash
grep -rn "Defaults\[" boringNotch/components/Settings/
grep -rn "Defaults\[" boringNotch/Core/
grep -rn "@Default(" boringNotch/components/
# Exclude NotchSettings.swift — that one is the allowed access point
```

**Step 1: For each offending settings view**

Replace `Defaults[.someKey]` with `@Environment(\.bindableSettings) var settings` and `settings.someProperty`.

If the property doesn't exist on `NotchSettings` protocol yet:
1. Add it to `NotchSettings` protocol in `NotchSettings.swift`
2. Add implementation in `DefaultsNotchSettings`
3. Add mock in `MockNotchSettings`
4. Then use `settings.someProperty` in the view

**Step 2: For non-settings views**

Replace `Defaults[.]` with `@Environment(\.settings) var settings` (read-only protocol).

**Step 3: Build + test**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50
```

**Step 4: Commit per file or per related group**

```bash
git commit -m "refactor: replace direct Defaults access with settings environment in [ViewName]"
```

---

### Task 7: Split `NotchSettings` Protocol (ISP Violation)

**Files:**
- Modify: `boringNotch/Core/NotchSettings.swift`

`NotchSettings` has 50+ properties. No consumer needs all of them. This violates Interface Segregation.

**Step 1: Group properties by domain**

Read the protocol and tag each property:
- `AppearanceSettings` — colors, corner radii, sizing, animation speed
- `NotchBehaviorSettings` — hover delays, open/close triggers, sneak peek config
- `MediaSettings` — music controller preference, lyrics, sneak peek for media
- `HUDSettings` — HUD style, show/hide conditions
- `FeatureSettings` — which plugins are enabled by default

**Step 2: Create focused sub-protocols**

```swift
protocol AppearanceSettings {
    var cornerRadius: CGFloat { get }
    // ...
}

protocol NotchBehaviorSettings {
    var hoverDelay: TimeInterval { get }
    // ...
}
```

**Step 3: `NotchSettings` becomes a composition**

```swift
protocol NotchSettings: AppearanceSettings, NotchBehaviorSettings, MediaSettings, HUDSettings, FeatureSettings {}
```

This is additive — existing code using `any NotchSettings` still works. Individual views can now narrow to `@Environment(\.settings) var settings: any AppearanceSettings` if they only need appearance.

**Step 4: Update `MockNotchSettings` and `DefaultsNotchSettings`**

Both already conform to `NotchSettings` — they automatically satisfy the sub-protocols since they implement all properties.

**Step 5: Build**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

**Step 6: Commit**

```bash
git commit -m "refactor: split NotchSettings into focused sub-protocols (ISP)"
```

---

### Task 8: Wire `BoringViewCoordinator` Remaining `.shared` Points

**Context:** 4 remaining `.shared` usage points were marked "acceptable" in the old plan. They're now addressable since `AppObjectGraph` (Task 5) provides a proper injection root.

**Files:**
- `boringNotch/BoringViewCoordinator.swift`
- `boringNotch/boringNotchApp.swift` (line ~180)
- `boringNotch/components/Settings/SettingsWindowController.swift` (line ~72)
- `boringNotch/models/BoringViewModel.swift` (line ~180, convenience init)
- `boringNotch/Core/NotchContentRouter.swift` (line ~230, preview only)

**Step 1: Replace app-level `.shared` usage**

In `AppObjectGraph`, construct `BoringViewCoordinator` normally (no `.shared`). Pass via environment or init injection.

**Step 2: Fix `SettingsWindowController`**

Instead of `BoringViewCoordinator.shared`, inject coordinator at construction time from `AppObjectGraph`.

**Step 3: Fix `BoringViewModel` convenience init**

Remove convenience init that uses `.shared`. Callers must provide the coordinator.

**Step 4: Fix preview usage in `NotchContentRouter`**

Preview can use a mock or lightweight coordinator stub. No `.shared` in production paths.

**Step 5: Once all consumers are migrated, remove `static let shared`**

```swift
// Delete this line from BoringViewCoordinator
static let shared = BoringViewCoordinator()
```

**Step 6: Build + test**

```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50
```

**Step 7: Commit**

```bash
git commit -m "refactor: eliminate last BoringViewCoordinator.shared usage points"
```

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
| 1 | All 8 known violations fixed. Zero files > 300 lines. No direct `Defaults[.]` outside `NotchSettings.swift`. No `.shared` except system APIs. Build green, tests pass. |
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
