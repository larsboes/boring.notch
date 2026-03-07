# boringNotch — PRD + Implementation Plan

**Goal:** Take boringNotch from plugin foundation to a clean, extensible notch platform with polished UX, data portability, automation hooks, and a path to third-party plugins.

**Architecture:** Plugin-first + DI via ServiceContainer + @Observable/@MainActor throughout. Every feature is a plugin. Views never construct services. All cross-plugin communication via PluginEventBus.

**Tech Stack:** Swift 5.9+, SwiftUI/AppKit, Defaults (settings), Combine (publishers), XPC helper, Sparkle (updates), Lottie (animations), KeyboardShortcuts

**Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
**Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`

---

## Current State (2026-03-07)

**Working branch:** `refactor/singleton-elimination-tier3`
**All branches synced:** `main` = `developer` = working branch

| Phase | Status | Summary |
|-------|--------|---------|
| 1 — Architecture Cleanup | ✅ Complete | Zero violations: no direct Defaults, no singletons, no files >300L, all @Observable |
| 1b — Observable Migration | ✅ Complete | Zero ObservableObject/Published. Event bus for all HUD show-calls. Deprecated code deleted. |
| 2 — Hover Overhaul | ✅ Complete | Heartbeat-based hover, dual hover zones, 11 unit tests. Manual verification pending. |
| 3 — Data Portability | ✅ Complete | ExportablePlugin protocol. Music, Calendar, Shelf export. Export UI in Settings. |
| 4 — Animation Polish | **Active** | StandardAnimations system in place. Duration tuning + staggered content next. |
| 5 — New Plugins | Planned | HabitTracker + Pomodoro |
| 6 — Automation | Planned | App Intents, URL scheme |
| 7 — Local API | Planned | REST + WebSocket at localhost:19384 |
| 8 — Third-Party Plugins | Planned | .boringplugin bundle format |

### Integrated Community PRs

| Feature | Original PR |
|---------|-------------|
| Sneak peek duration customization | #897 |
| Auto-disable HUD on disconnected displays | #895 |
| Screen recording live activity | #804 |
| Mood face customization | #798 |
| Clipboard history + note-taking (SQLite-backed) | #788 |
| Animated face with mouse tracking | #751 |

---

## CI Infrastructure

**Pipeline:** `.github/workflows/cicd.yml` — runs on every push/PR, 3 parallel jobs:

| Job | Runner | What |
|-----|--------|------|
| **Build** | `macos-latest` | Release build via `xcodebuild` |
| **Test** | `macos-latest` | All unit tests |
| **Arch Check** | `ubuntu-latest` | 300-line limit, Defaults rules, @Published ban, singleton ban |

---

## Phase 4 — Animation Polish (Active)

**Goal:** Make open/close transitions feel as polished as Apple's Dynamic Island. Smooth, interruptible, content-aware.

### Task 12: Tune phase transition timing

**Status:** Ready to implement

The `StandardAnimations` system is in place (`boringNotch/animations/drop.swift`). Current values:
- `openDuration`: 400ms (gates `.opening` → `.open` phase transition)
- `closeDuration`: 350ms (gates `.closing` → `.closed` phase transition)

The spring's visual settling happens before the mathematical settling. These durations feel "stuck."

**Changes:**
- Reduce `openDuration` to 350ms, `closeDuration` to 300ms
- Verify no phase-flip-before-settle on slower Macs
- Test: rapid open/close cycling doesn't break state machine

**Files:** `boringNotch/animations/drop.swift`, `boringNotch/models/BoringViewModel+OpenClose.swift`

---

### Task 13: Staggered content fade-in

**Status:** Ready to implement

Content currently appears instantly when the notch opens. Should fade in progressively as borders expand.

**Changes:**
- Add opacity transitions to content views, synchronized with open animation
- Use existing `StandardAnimations.staggered(index:)` (already wired in `NotchHomeView`)
- Stagger order: header (index 0) → primary content (1) → secondary content (2) → controls (3)
- Content should fade out immediately on close (no stagger — close should feel decisive)

**Files:** `boringNotch/components/Notch/NotchHomeView.swift`, plugin view files

---

### Task 14: Spring curve refinement

**Status:** After Tasks 12-13

Fine-tune the spring parameters based on real-device feel:

| Animation | Current | Tuning direction |
|-----------|---------|------------------|
| `open` | response: 0.38, damping: 0.78 | May need slightly higher damping (less bounce) |
| `close` | response: 0.35, damping: 0.92 | Good — decisive and quick |
| `interactive` | interactiveSpring(response: 0.3) | Test with gestures |
| `staggered` | spring(response: 0.4, damping: 0.8) + delay | Delay intervals may need tightening |

---

### Task 15: Gesture-driven progressive open (Future)

**Status:** Architecture block — design needed

Replace fire-and-forget animations with continuous gesture-driven expansion. The notch height/width maps 1:1 to a gesture translation value, making it interruptible and scrubable.

**Requires:**
- Move from phase-triggered animations to a continuous 0→1 progress value
- Map NSTrackingArea translation or DragGesture to progress
- All content views bind to progress for opacity/scale
- Substantial refactor of `BoringViewModel+OpenClose`

**Defer until Tasks 12-14 are shipped and validated.**

---

## Phase 5 — New Built-In Plugins

**Goal:** Ship 2 high-value plugins to validate the plugin API is first-class and exportable.

**Prerequisite:** Phase 3 complete ✅

### Task 16: HabitTrackerPlugin

**Directory:** `boringNotch/Plugins/BuiltIn/HabitTrackerPlugin/`

- Conforms to `NotchPlugin` + `ExportablePlugin` (JSON + CSV)
- Closed notch: dots for today's habits (filled = done, hollow = pending)
- Expanded: habit list, tap to complete, streak counter
- Data stored in `~/Library/Application Support/boringNotch/habits.json`
- Priority `.background` normally, `.normal` if habit due within 1 hour
- Tests: `HabitStoreTests`, `HabitPluginTests`

### Task 17: PomodoroPlugin

**Directory:** `boringNotch/Plugins/BuiltIn/PomodoroPlugin/`

- Conforms to `NotchPlugin` + `ExportablePlugin` (CSV compatible with Toggl/Clockify)
- Closed notch: circular progress ring, color-coded by session type
- Expanded: start/pause/skip, work/break labels, session count
- Priority `.high` when running, `nil` when idle
- Publishes `SneakPeekRequestedEvent` on session complete
- Optional macOS Focus mode integration during work sessions
- Tests: `PomodoroTimerTests` (pure unit test)

---

## Phase 6 — Automation & Integrations

**Goal:** Make boringNotch controllable from outside the app.

### Task 18: App Intents (Shortcuts)

6 intents: OpenNotch, CloseNotch, StartPomodoro, CompleteHabit, AddToShelf, ExportData. All route through `PluginManager`, no singleton access.

### Task 19: URL Scheme Handler

Scheme: `boringnotch://`. Routes: open, close, shelf/add, plugin actions, export. Dedicated `URLSchemeHandler` type, registered in Info.plist.

---

## Phase 7 — Local API Server

**Goal:** REST + WebSocket at `localhost:19384`. Enables Raycast, browser extensions, CLI scripting.

**Design session needed before implementation.**

MVP endpoints: plugin list/data/actions, notch state/open/close, now-playing, WebSocket event stream. Bind `127.0.0.1` only.

---

## Phase 8 — Third-Party Plugin Distribution

**Goal:** `.boringplugin` bundle format + plugin discovery UI.

**Separate design document when Phase 7 is complete.**

Requirements: signed Swift package bundles, permission manifests, approval UI, plugin browser in Settings, `~/Library/Application Support/boringNotch/Plugins/` discovery.

---

## Success Metrics

| Phase | Done When |
|-------|-----------|
| 1 + 1b | ✅ Zero violations. Build green. |
| 2 | ✅ Heartbeat hover, dual zones, 11 tests. |
| 3 | ✅ ExportablePlugin + UI. |
| 4 | Open/close feels smooth and interruptible. No "stuck" phase transitions. Content fades in progressively. |
| 5 | HabitTracker + Pomodoro shipped. Both export. Both tested. |
| 6 | All App Intents in Shortcuts. URL scheme routes work. |
| 7 | localhost:19384 responds. WebSocket streams events. |
| 8 | External plugin loads from ~/Library/Application Support/boringNotch/Plugins/. |

---

## Key Constraints

- **300-line hard limit per file**
- **No new singletons** — `AppObjectGraph` is the only DI root
- **Protocol before implementation** — new services get a protocol first
- **Build must stay green** — no broken intermediate commits
- **One commit per logical unit** — enables rollback
- **Tests before ship** — every new plugin gets unit tests

## Files to Not Touch

- `boringNotch/Plugins/Core/NotchPlugin.swift` — stable protocol
- `boringNotch/Plugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `boringNotch/Core/NotchStateMachine.swift` — pure, tested, stable
- `boringNotch/private/CGSSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only
