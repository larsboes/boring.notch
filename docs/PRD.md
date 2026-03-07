# boringNotch — PRD + Implementation Plan

**Goal:** Transform boringNotch from a polished notch replacement into a **local-first ambient display platform** — beautiful UX, API-driven extensibility, and a plugin ecosystem.

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
| 2 — Hover Overhaul | ✅ Complete | Heartbeat-based hover, dual hover zones, 11 unit tests. |
| 3 — Data Portability | ✅ Complete | ExportablePlugin protocol. Music, Calendar, Shelf export. Export UI in Settings. |
| 4 — Animation Polish | **Active** | Duration tuning + staggered header fade done. Spring refinement + gesture-driven open remaining. |
| 5 — Local API | **Next** | REST + WebSocket — the foundation for all external integrations |
| 6 — API-Powered Plugins | Planned | Teleprompter, DisplaySurface |
| 7 — Automation | Planned | App Intents, URL scheme |
| 8 — Standalone Plugins | ✅ Complete | HabitTracker + Pomodoro shipped as dedicated tabs (right-side header icons). |
| 9 — Third-Party Distribution | Planned | .boringplugin bundle format |

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

**Goal:** Make open/close transitions feel as polished as Apple's Dynamic Island.

### Task 12: Tune phase transition timing ✅ Done

Reduced `openDuration` 400→350ms, `closeDuration` 350→300ms. Removes the "stuck" feeling between phases.

### Task 13: Staggered content fade-in ✅ Done

Added `.animation(StandardAnimations.staggered(index:))` to `BoringHeader` — left tabs at index 1, right system items at index 2. Content fades in progressively as borders expand.

### Task 14: Spring curve refinement

**Status:** Test on device, tune if needed

| Animation | Current | Tuning direction |
|-----------|---------|------------------|
| `open` | response: 0.38, damping: 0.78 | May need slightly higher damping (less bounce) |
| `close` | response: 0.35, damping: 0.92 | Good — decisive and quick |
| `interactive` | interactiveSpring(response: 0.30, damping: 0.86) | Tuned for less overshoot during scrubbing |
| `staggered` | spring(response: 0.28, damping: 0.88) + 0.03s delay | Tightened intervals |

### Task 15: Gesture-driven progressive open (Future)

**Status:** Architecture block — design needed

Replace fire-and-forget animations with continuous gesture-driven expansion. Notch height/width maps 1:1 to a gesture translation value — interruptible and scrubbable. Substantial refactor of `BoringViewModel+OpenClose`. Defer until Tasks 12-14 shipped.

---

## Phase 5 — Local API Server

**Goal:** REST + WebSocket API at `localhost:19384`. This is the foundation — it turns boringNotch from a standalone app into a **local-first ambient display platform**. Anything that can `curl` can use the notch.

**Why this comes first:** Every future integration (Teleprompter, Raycast, browser extensions, AI agents, CLI tools) needs this. Building it early means every subsequent plugin can be API-driven from day one.

### Architecture

```
External clients (curl, Raycast, scripts, browser ext)
        │
        ▼
  LocalAPIServer (Network.framework, bound to 127.0.0.1:19384)
        │
        ├── REST routes → PluginManager / ServiceContainer
        │
        └── WebSocket /events → PluginEventBus (bidirectional)
```

**Security model:**
- Bind `127.0.0.1` only — no network exposure by default
- Optional bearer token auth (stored in Keychain) for remote use later
- Rate limiting on write endpoints (10 req/s default)

### Task 16: Core API Server

**Directory:** `boringNotch/LocalAPI/`

**Files:**
- `LocalAPIServer.swift` — HTTP server using `Network.framework` (NWListener). No external dependencies.
- `APIRouter.swift` — route matching + dispatch
- `APIResponse.swift` — Codable response envelope (`{ "ok": true, "data": ... }`)

**Lifecycle:** Starts with app, stops on quit. Managed by `AppObjectGraph`, injected as a service.

### Task 17: REST Endpoints

**Core endpoints (MVP):**

```
# Notch control
GET  /api/v1/notch/state              → { phase, screen, size }
POST /api/v1/notch/open               → open notch
POST /api/v1/notch/close              → close notch
POST /api/v1/notch/toggle             → toggle

# Plugin system
GET  /api/v1/plugins                  → list active plugins + state
GET  /api/v1/plugins/{id}             → plugin detail + capabilities
GET  /api/v1/plugins/{id}/data        → exported data (JSON)
POST /api/v1/plugins/{id}/action      → trigger plugin action

# Music (convenience — routes to MusicPlugin)
GET  /api/v1/music/now-playing        → current track info
POST /api/v1/music/play-pause         → toggle playback
POST /api/v1/music/next               → next track
POST /api/v1/music/previous           → previous track

# Display surface (for API-powered plugins)
POST /api/v1/display/text             → push text to DisplaySurface plugin
POST /api/v1/display/markdown         → push markdown
POST /api/v1/display/progress         → push progress bar (label + 0-1 value)
POST /api/v1/display/clear            → clear display

# Teleprompter (when plugin installed)
POST /api/v1/teleprompter/load        → load script { text, speed?, fontSize? }
POST /api/v1/teleprompter/start       → start scrolling
POST /api/v1/teleprompter/pause       → pause
POST /api/v1/teleprompter/stop        → stop + reset
GET  /api/v1/teleprompter/state       → { position, isScrolling, remainingTime }
```

All write endpoints return `{ "ok": true }` or `{ "ok": false, "error": "..." }`.

### Task 18: WebSocket Event Stream

```
WS /api/v1/events
```

**Server → Client events:**
```json
{ "type": "notch.opened", "data": { "screen": "main" } }
{ "type": "notch.closed", "data": {} }
{ "type": "music.changed", "data": { "title": "...", "artist": "..." } }
{ "type": "plugin.stateChanged", "data": { "id": "...", "state": "..." } }
{ "type": "hover.entered", "data": {} }
{ "type": "hover.exited", "data": {} }
```

**Client → Server commands** (bidirectional):
```json
{ "command": "display.text", "data": { "text": "Hello from script" } }
{ "command": "notch.open", "data": {} }
```

Events sourced from `PluginEventBus` — the WebSocket bridge subscribes to all events and forwards. This means any `PluginEventBus` event is automatically available to external clients.

### Task 19: CLI companion (optional)

Simple shell script or Swift CLI that wraps the API for ergonomic use:

```bash
notchctl open
notchctl close
notchctl display "Build passed ✓"
notchctl music now-playing
notchctl teleprompter load < script.txt
notchctl teleprompter start --speed 2
```

Ships as a separate binary in the app bundle, symlinked to `/usr/local/bin/notchctl` on install.

---

## Phase 6 — API-Powered Plugins

**Goal:** Prove the Local API works with two high-value plugins that accept external data. These are the "killer demos" — they show boring.notch isn't just a notch replacement but a general-purpose ambient display.

### Task 20: TeleprompterPlugin

**Directory:** `boringNotch/Plugins/BuiltIn/TeleprompterPlugin/`

**Inspiration:** Moody (notch teleprompter for Mac). Text displayed right next to the camera — natural eye contact during video calls and presentations.

**Files:**
- `TeleprompterPlugin.swift` — plugin class, API endpoint handler
- `TeleprompterState.swift` — `@Observable` state: script text, scroll position, speed, font size
- `TeleprompterScrollEngine.swift` — pure scroll logic (speed, position, auto-pause on section breaks)
- `Views/TeleprompterClosedView.swift` — subtle indicator (pulsing dot when script loaded, static when idle)
- `Views/TeleprompterExpandedView.swift` — scrolling text display, speed slider, progress bar
- `Views/TeleprompterSettingsView.swift` — default speed, font size, color theme, keyboard shortcuts

**Behavior:**
- **Closed notch:** small indicator dot (green = script loaded, pulsing = scrolling, none = empty)
- **Expanded notch:** 2-3 lines of text visible, current line highlighted, auto-scrolling at configurable speed
- **Presentation mode:** notch stays expanded at fixed height, other plugins hidden, text scrolls continuously
- **Input sources:**
  - Manual: paste text or load .txt/.md file via file picker
  - API: `POST /api/v1/teleprompter/load` with text body
  - Clipboard: "Load from clipboard" button
- **Controls:** play/pause (spacebar), speed +/- (arrow keys), restart, font size
- **Smart features:**
  - Auto-pause on paragraph breaks (configurable pause duration)
  - Section markers (## headings) shown as progress milestones
  - Estimated time remaining based on current speed

**Display priority:** `.high` when scrolling, `.normal` when loaded but paused, `nil` when empty.

**API integration:** Registers endpoints with `LocalAPIServer` on activate. Deregisters on deactivate.

**Tests:** `TeleprompterScrollEngineTests` (pure unit test — speed, position, pause logic).

**Use cases:**
- Conference talks (your CFP strategy — dogfood this)
- Video calls with talking points
- YouTube recording with script
- AI agent pushes real-time talking points during meetings

---

### Task 21: DisplaySurfacePlugin

**Directory:** `boringNotch/Plugins/BuiltIn/DisplaySurfacePlugin/`

**Concept:** A generic "dumb terminal" plugin. It renders whatever the API tells it to. No built-in logic — it's purely a display surface for external tools.

**Files:**
- `DisplaySurfacePlugin.swift` — plugin class, API endpoint handler
- `DisplayContent.swift` — enum: `.text(String)`, `.markdown(String)`, `.progress(label: String, value: Double)`, `.keyValue([(String, String)])`, `.clear`
- `Views/DisplayClosedView.swift` — compact: single-line text or mini progress bar
- `Views/DisplayExpandedView.swift` — full content render (markdown, progress, key-value pairs)

**Behavior:**
- **Closed notch:** last pushed content in compact form (truncated text or mini progress bar)
- **Expanded notch:** full content rendering
- **Content pushed exclusively via API** — no built-in UI for content creation
- **Content persists until replaced or cleared** — survives notch open/close cycles
- **Auto-dismiss:** optional TTL on content (e.g., `{ "text": "Done!", "ttl": 5 }` disappears after 5s)

**Display priority:** `.normal` when content present, `nil` when empty.

**Example integrations:**

| Script | What it pushes | Notch shows |
|--------|---------------|-------------|
| CI watcher | `POST /display/progress {"label": "Build", "value": 0.73}` | Progress bar |
| Stock ticker | `POST /display/text {"text": "AAPL $247.30 ▲2.1%"}` | Ticker text |
| Ollama stream | `POST /display/markdown` per token | Streaming LLM response |
| Meeting summarizer | `POST /display/text {"text": "Key: budget approved"}` | Real-time notes |
| Deploy script | `POST /display/text {"text": "Deployed v2.4.1 ✓", "ttl": 10}` | Temporary status |

**Tests:** `DisplaySurfacePluginTests` (content update, TTL expiry, clear behavior).

---

## Phase 7 — Automation & Integrations

**Goal:** Make boringNotch controllable from macOS automation frameworks.

### Task 22: App Intents (Shortcuts)

6 intents: OpenNotch, CloseNotch, StartPomodoro, CompleteHabit, AddToShelf, ExportData. All route through `PluginManager`, no singleton access.

### Task 23: URL Scheme Handler

Scheme: `boringnotch://`. Routes: open, close, shelf/add, plugin actions, export. Dedicated `URLSchemeHandler` type, registered in Info.plist.

---

## Phase 8 — Standalone Plugins ✅ Complete

**Goal:** Ship 2 standalone plugins to further validate the plugin API.

### Task 24: HabitTrackerPlugin ✅ Done

- Conforms to `NotchPlugin` with full `activate()`/`deactivate()` lifecycle
- Closed notch: dot indicators for today's habits
- Expanded: habit list with tap-to-complete, streak counter, add/remove habits
- Data persisted via `HabitStore` (UserDefaults-backed with JSON coding)
- Dedicated "Habits" tab — icon button (✓) on right side of `BoringHeader`
- Conditionally shown based on `settings.showHabitTracker`

### Task 25: PomodoroPlugin ✅ Done

- Conforms to `NotchPlugin` with configurable `PomodoroTimer`
- Closed notch: circular progress ring, color-coded by session type (work/short break/long break)
- Expanded: compact horizontal layout — 80px timer ring + controls (play/pause, reset, skip)
- Session tracking with dots showing progress toward long break
- Dedicated "Focus" tab — icon button (⏱) on right side of `BoringHeader`
- Conditionally shown based on `settings.showPomodoro`

### UI Architecture

- **Moved out of `NotchHomeView`** — plugins no longer clutter the home panel
- **Right-side header icons** in `BoringHeader` toggle their respective views (tap again = back to Home)
- **Routed via `NotchContentRouter`** with new `.habitTracker` / `.pomodoro` cases in `NotchViews` enum

---

## Phase 9 — Third-Party Plugin Distribution

**Goal:** `.boringplugin` bundle format + plugin discovery UI.

**Separate design document when Phase 7 is complete.**

Requirements: signed Swift package bundles, permission manifests, approval UI, plugin browser in Settings, `~/Library/Application Support/boringNotch/Plugins/` discovery.

---

## Vision: The Notch as Ambient Display Platform

```
┌─────────────────────────────────────────────────────────────────┐
│                    External World                                │
│  curl / Raycast / Browser Ext / Python / AI Agents / Shortcuts  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ REST + WebSocket (localhost:19384)
┌──────────────────────────▼──────────────────────────────────────┐
│                    LocalAPIServer                                │
│  Routes → PluginManager    WebSocket ↔ PluginEventBus           │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    Plugin Layer                                   │
│  ┌──────────┐ ┌──────────────┐ ┌────────────┐ ┌─────────────┐  │
│  │ Music    │ │ Teleprompter │ │ Display    │ │ Calendar    │  │
│  │ Battery  │ │ Pomodoro     │ │ Surface    │ │ Shelf       │  │
│  │ Webcam   │ │ HabitTracker │ │ (generic)  │ │ Clipboard   │  │
│  └──────────┘ └──────────────┘ └────────────┘ └─────────────┘  │
│        Built-in              API-powered         Built-in        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    Service Layer                                  │
│  ServiceContainer → Protocol-based services → System APIs        │
└─────────────────────────────────────────────────────────────────┘
```

**The key insight:** The notch is the most camera-adjacent, always-visible, least-intrusive display surface on a MacBook. Making it API-driven turns it into a **personal HUD** for any local tool.

---

## Success Metrics

| Phase | Done When |
|-------|-----------|
| 1 + 1b | ✅ Zero violations. Build green. |
| 2 | ✅ Heartbeat hover, dual zones, 11 tests. |
| 3 | ✅ ExportablePlugin + UI. |
| 4 | Open/close feels smooth and interruptible. No "stuck" phase transitions. Content fades in progressively. |
| 5 | `curl localhost:19384/api/v1/notch/state` returns valid JSON. WebSocket streams events. `notchctl` works. |
| 6 | Teleprompter scrolls text fed via API. DisplaySurface renders arbitrary content from `curl`. |
| 7 | All App Intents in Shortcuts. URL scheme routes work. |
| 8 | ✅ HabitTracker + Pomodoro shipped as dedicated tabs. Compact notch-friendly layouts. |
| 9 | External plugin loads from ~/Library/Application Support/boringNotch/Plugins/. |

---

## Key Constraints

- **300-line hard limit per file**
- **No new singletons** — `AppObjectGraph` is the only DI root
- **Protocol before implementation** — new services get a protocol first
- **Build must stay green** — no broken intermediate commits
- **One commit per logical unit** — enables rollback
- **Tests before ship** — every new plugin gets unit tests
- **API-first for new plugins** — if a plugin can be API-driven, it should be

## Files to Not Touch

- `boringNotch/Plugins/Core/NotchPlugin.swift` — stable protocol
- `boringNotch/Plugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `boringNotch/Core/NotchStateMachine.swift` — pure, tested, stable
- `boringNotch/private/CGSSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only
