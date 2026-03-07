# boringNotch — PRD + Implementation Plan

**Goal:** Transform boringNotch from a polished notch replacement into a **local-first ambient display platform** — beautiful UX, API-driven extensibility, and a plugin ecosystem.

**Architecture:** Plugin-first + DI via ServiceContainer + @Observable/@MainActor throughout. Every feature is a plugin. Views never construct services. All cross-plugin communication via PluginEventBus.

**Tech Stack:** Swift 5.9+, SwiftUI/AppKit, Defaults (settings), Combine (publishers), XPC helper, Sparkle (updates), Lottie (animations), KeyboardShortcuts

**Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
**Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`

### Key Constraints

- **300-line hard limit per file**
- DDD & SOLID Architecture
- **No new singletons** — `AppObjectGraph` is the only DI root
- **Protocol before implementation** — new services get a protocol first
- **Build must stay green** — no broken intermediate commits
- **One commit per logical unit** — enables rollback
- **Tests before ship** — every new plugin gets unit tests
- **API-first for new plugins** — if a plugin can be API-driven, it should be

### Files to Not Touch

- `Plugins/Core/NotchPlugin.swift` — stable protocol
- `Plugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `Core/NotchStateMachine.swift` — pure and tested; only modify for state logic changes
- `private/CGSSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only

---

## Current State (2026-03-07)

**Working branch:** `refactor/singleton-elimination-tier3`
**All branches synced:** `main` = `developer` = working branch

| Phase | Status | Summary |
|-------|--------|---------|
| 1, 1b, 2, 3, 4a, 8 | ✅ Shipped | Plugin arch, @Observable migration, heartbeat hover, data export, architecture debt cleanup, HabitTracker + Pomodoro, battery optimization |
| 4 — Animation Polish | **Active** | Tasks 12-13 done. Task 14 (spring curves) needs device tuning. New: Tasks 16-20 (choreography, shadow, album art morph, sleep→completion). Task 15 (gesture-driven) deferred. |
| 5 — Local API | **MVP shipped; hardening next** | Core REST + WebSocket live. Dynamic route registration + path params added. Plugin/music routes, auth, rate limiting remain. |
| 6 — API-Powered Plugins | Planned | Teleprompter, DisplaySurface |
| 6b — On-Device AI Assist (Optional) | Planned | Foundation Models-backed script assist for Teleprompter + Display |
| 7 — Automation | Planned | App Intents, URL scheme |
| 9 — Third-Party Distribution | Planned | .boringplugin bundle format |

---

## Phase 4 — Animation Polish (Active)

**Goal:** Make open/close transitions feel as polished as Apple's Dynamic Island.

**Done:** Task 12 (phase timing) ✅, Task 13 (staggered header fade) ✅

### Task 14: Spring curve refinement

**Status:** Paused — values tuned, needs on-device feel testing

| Animation | Current | Tuning direction |
|-----------|---------|------------------|
| `open` | response: 0.38, damping: 0.78 | May need slightly higher damping (less bounce) |
| `close` | response: 0.35, damping: 0.92 | Good — decisive and quick |
| `interactive` | interactiveSpring(response: 0.30, damping: 0.86) | Tuned for less overshoot during scrubbing |
| `staggered` | spring(response: 0.28, damping: 0.88) + 0.03s delay | Tightened intervals |

### Task 16: Stagger timing + shadow easing (Quick wins)

**Status:** Not started

**Stagger:** Bump `staggered(index:)` delay from `0.03s` → `0.06s` for perceptible sequencing. Consider softer spring (`response: 0.32`) for staggered items. Order: header-left (tabs) index 0, header-right (icons) index 1, content panels 2+.

**Shadow:** Replace linear `0.7 * animationProgress` with late-onset easing — no shadow until `animationProgress > 0.4`, then ramp via `pow(progress, 2.5)`. Shadow should appear *after* notch has mostly expanded.

**Border:** Luminance easing — linger slightly on close (don't disappear linearly).

**Files:** `drop.swift`, `ContentView.swift`

### Task 17: Content choreography — open

**Status:** Not started

Content *grows out of* the notch center, not just fades in.

**Current problem:** Content visibility is keyed to `notchState` (binary: `.open` or not). Everything fades in simultaneously via opacity + blur. No sense of content emerging from the notch.

**Fix:**
- Key content opacity/scale to `animationProgress` (continuous 0→1), not `notchState`
- Each content panel: `scaleEffect(lerp(0.92, 1.0, progress))` + `opacity(smoothstep(0.3, 0.8, progress))`
- Content begins revealing at `animationProgress > 0.3` (during `.opening` phase, not after `.open`)
- Header elements slide in with subtle `offset(y: lerp(-4, 0, progress))`
- Stagger between panels uses Task 16 timing

**Files:** `NotchHomeView.swift`, `BoringHeader.swift`, `ContentView+Appearance.swift` (add `smoothstep` helper)

### Task 18: Content choreography — close

**Status:** Not started | Depends on: Task 17

Reverse of Task 17 — content *retracts into* the notch before the shell finishes closing.

**Approach:** Since content is keyed to `animationProgress` (from Task 17), the close path is mostly free — progress goes 1→0 and content scales down + fades. Verify stagger runs in reverse order (last-in, first-out).

**Optional enhancement:** Slightly faster content exit than shell close — content should be ~80% gone while notch is still at 50% size. Achievable by remapping content progress: `pow(animationProgress, 0.7)` gives content a head start on disappearing.

**Files:** `NotchHomeView.swift`, `BoringHeader.swift`

### Task 19: Matched album art transition

**Status:** Not started | Depends on: Task 17

Album art thumbnail in closed state smoothly morphs into expanded player art via `matchedGeometryEffect`.

**Current state:** `albumArtNamespace` is threaded through `ContentView` → `NotchContentRouter` → `NotchHomeView` but no `matchedGeometryEffect` connects closed↔open art.

**Implementation:**
- Add `.matchedGeometryEffect(id: "albumArt", in: namespace)` to closed music plugin's album art thumbnail
- Add same to expanded `PluginMusicPlayerView` album art
- Manage `zIndex` during transition to prevent clipping
- Transition: art morphs position + size while notch expands. Classic Dynamic Island feel.

**Files:** Closed music plugin view, `PluginMusicPlayerView.swift`, `NotchContentRouter.swift`

### Task 20: Replace `Task.sleep` phase completion

**Status:** Not started

`open()` and `close()` use `Task.sleep(for: duration)` then check `guard self.phase == .opening`. This is fragile — rapid open/close sequences can race.

**Options:**
- **Option A (preferred, macOS 14+):** `withAnimation(.spring(...)) { } completion: { }` — animation-framework callback
- **Option B (fallback):** Store completion task, cancel previous on new open/close (re-entrancy guard)
- **Option C (advanced):** Drive phase transitions from `animationProgress` thresholds

**Files:** `BoringViewModel+OpenClose.swift`

### Task 15: Gesture-driven progressive open (Future)

**Status:** Deferred — needs design

Replace fire-and-forget animations with continuous gesture-driven expansion. Notch height/width maps 1:1 to gesture translation — interruptible and scrubbable. Substantial refactor of `BoringViewModel+OpenClose`. Defer until Tasks 16-20 shipped.

---

## Phase 4a — Architecture Debt ✅ (Completed 2026-03-07)

<details>
<summary>All 9 audit items resolved — click to expand</summary>

**Goal:** Fix regressions discovered in the 2026-03-07 architecture audit. Violations accumulated during Phase 2-4 feature work.

**Migration health at time of audit:** 127 legacy files (`managers/`, `models/`, `components/`) vs 95 modern files (`Core/`, `Plugins/`, `MediaControllers/`). Legacy was 57% of the codebase.

| Task | What | Resolution |
|------|------|------------|
| 4a.1 | `DefaultsNotchSettings.swift` 457 lines (>300 limit) | Split into 5 files by MARK section |
| 4a.2 | Duplicate stub files in `Core/` | Stubs deleted, real files in `Plugins/` referenced |
| 4a.3 | `NotchStateMachine` depended on concrete `BoringViewCoordinator` | Extracted `NotchAnimationStateProviding` protocol |
| 4a.4 | 3 files bypassed `DefaultsNotchSettings` with direct `Defaults[.]` | Routed through settings protocols |
| 4a.5 | `NotificationCenterManager` missing `@MainActor` | Added `@MainActor` |
| 4a.6 | `QuickLookService.shared` unlisted singleton | Injected via `QuickLookServiceProtocol` in `ServiceContainer` |
| 4a.7 | `Plugins/Core/` listed as Domain but imports SwiftUI | CLAUDE.md DDD table updated — moved to Application layer |
| 4a.8 | `PluginContext.services` typed as concrete `ServiceContainer` | Deferred to Phase 9 (only needed for third-party plugin testing) |
| 4a.9 | `struct sneakPeek` lowercase naming | Renamed to `SneakPeek` codebase-wide |

**Verified:** Zero files >300 lines, zero duplicate files, zero Defaults leaks, build green, 24 tests passing.

</details>

---

## Phase 5 — Local API Server

**Goal:** Stabilize and expand the existing REST + WebSocket API at `localhost:19384`. This is the foundation — it turns boringNotch from a standalone app into a **local-first ambient display platform**. Anything that can `curl` can use the notch.

**Status:** Core MVP is already implemented under `boringNotch/private/LocalAPI/` and starts with app lifecycle via `LocalAPIServerController` in `AppObjectGraph`/`boringNotchApp`.

**Why this comes first:** Every future integration (Teleprompter, Raycast, browser extensions, AI agents, CLI tools) needs this. With the base server already in place, Phase 5 now focuses on hardening and route expansion so subsequent plugins can be API-driven from day one.

### Architecture

```
External clients (curl, Raycast, scripts, browser ext)
        │
        ▼
  LocalAPIServer (Network.framework, port 19384)
        │
        ├── REST routes → PluginManager / ServiceContainer
        │
        └── WebSocket /events → PluginEventBus (bidirectional)
```

**Security model:**
- [ ] Enforce loopback-only bind (`127.0.0.1`) by default
- [ ] Optional bearer token auth (stored in Keychain) for remote use later
- [ ] Rate limiting on write endpoints (10 req/s default)

### Task 5.1: Core API Server ✅

**Implemented.** `boringNotch/private/LocalAPI/` — HTTP server via `Network.framework` (NWListener), route matching, Codable response envelope, WebSocket client lifecycle, app lifecycle wiring. No external dependencies.

### Task 5.2: REST Endpoints

**Status:** 🟡 Core routes shipped, expansion remaining

**Shipped:**
```
GET  /api/v1/notch/state              → { phase, screen, size }
POST /api/v1/notch/open               → open notch
POST /api/v1/notch/close              → close notch
POST /api/v1/notch/toggle             → toggle
```

**Router improvements shipped:** Dynamic route registration via `APIRouteRegistrar`, path-parameter matching (`/api/v1/plugins/{id}`), proper `404` vs `405` differentiation.

**Remaining:**

```
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
```

> **Note:** Teleprompter + DisplaySurface endpoints are defined in Phase 6 — they register their own routes when their plugins ship.

All write endpoints return `{ "ok": true }` or `{ "ok": false, "error": "..." }`.

### Task 5.3: WebSocket Event Stream

**Status:** 🟡 MVP shipped, schema hardening remaining

```
WS /api/v1/events
```

**Current behavior (implemented):**
- WebSocket upgrade on `/api/v1/events`
- Broadcast bridge from `PluginEventBus` to all connected clients
- Event payload currently normalized to `{ type, data }` with mapped type + metadata

**Target event taxonomy (remaining alignment):**
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

Events are sourced from `PluginEventBus` via the server controller bridge.

### Task 5.4: CLI companion (optional)

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

### Task 6.1: TeleprompterPlugin

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

**Endpoints (registered by plugin):**
```
POST /api/v1/teleprompter/load        → load script { text, speed?, fontSize? }
POST /api/v1/teleprompter/start       → start scrolling
POST /api/v1/teleprompter/pause       → pause
POST /api/v1/teleprompter/stop        → stop + reset
GET  /api/v1/teleprompter/state       → { position, isScrolling, remainingTime }
```

**Tests:** `TeleprompterScrollEngineTests` (pure unit test — speed, position, pause logic).

**Use cases:**
- Conference talks (your CFP strategy — dogfood this)
- Video calls with talking points
- YouTube recording with script
- AI agent pushes real-time talking points during meetings

---

### Task 6.2: DisplaySurfacePlugin

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

**Endpoints (registered by plugin):**
```
POST /api/v1/display/text             → push text to DisplaySurface plugin
POST /api/v1/display/markdown         → push markdown
POST /api/v1/display/progress         → push progress bar (label + 0-1 value)
POST /api/v1/display/clear            → clear display
```

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

## Phase 6b — On-Device AI Assist (Optional)

**Goal:** Add optional on-device text-generation assists without making core plugin behavior depend on AI availability.

**Scope boundary (hard rule):**
- Teleprompter scrolling/timing/rendering remains deterministic and fully usable without AI.
- AI is assistive only (rewrite, summarize, sectioning, marker generation).

### Task 6b.1: AI provider abstraction

**Files:**
- `Plugins/Services/AITextGenerationServiceProtocol.swift`
- `Plugins/Services/NoAITextGenerationService.swift`
- `Plugins/Services/FoundationModelsTextGenerationService.swift` (gated)

**Protocol (minimal):**
```swift
@MainActor
protocol AITextGenerationServiceProtocol {
    var isAvailable: Bool { get }
    func rewrite(_ text: String, style: String) async throws -> String
    func summarize(_ text: String) async throws -> String
    func section(_ text: String) async throws -> [String]
}
```

**Requirements:**
- `NoAITextGenerationService` is default and deterministic.
- Foundation Models provider is used only when available at runtime.
- No plugin depends directly on Foundation Models types.

### Task 6b.2: Teleprompter assist actions

**UI actions (expanded panel):**
- Rewrite script
- Summarize to bullet outline
- Generate section markers
- Estimate speaking time

**API endpoints (optional helpers):**
```
POST /api/v1/teleprompter/assist/rewrite
POST /api/v1/teleprompter/assist/summarize
POST /api/v1/teleprompter/assist/section
```

**Contract rule:** Existing Teleprompter endpoints (`load/start/pause/stop/state`) remain unchanged.

### Task 6b.3: Runtime gating + settings

**Settings:**
- Toggle: "Enable On-Device AI Assist"
- Availability status + reason
- Fallback message when unavailable

**Behavior:**
- If unavailable, assist actions return clear `ok: false` errors and suggest manual flow.
- No crashes/no-op ambiguity when model assets are not ready.

### Task 6b.4: Additional plugin opportunities (post-Teleprompter)

**DisplaySurfacePlugin (assistive formatting):**
- Summarize long pushed content into concise notch-safe cards.
- Convert raw logs/notes into bullet lists or key/value highlights.

**NotificationsPlugin (digest mode):**
- Merge bursts of notifications into "what matters now" summaries.
- Keep urgent items explicit while compressing low-priority noise.

**ClipboardPlugin (text cleanup):**
- Rewrite/clean copied text and extract action items.
- Convert messy notes into checklist-friendly output.

**CalendarPlugin (meeting briefs):**
- Generate compact "next up" summaries for upcoming events.
- Optional prep prompts for imminent meetings.

**HabitTracker/Pomodoro (coach summaries):**
- End-of-session recap text and next-action suggestions.
- Optional motivational copy with strict fallback to deterministic defaults.

**Constraint (all plugins):**
- AI assists are optional overlays only; no core plugin workflow may depend on AI availability.

### Task 6b.5: Tests

- Unit tests for provider selection and fallback behavior.
- Endpoint tests for assist routes (success/unavailable/error mapping).
- Teleprompter regression tests proving non-AI flow still passes.
- Regression tests for at least one non-Teleprompter assist flow (DisplaySurface or Clipboard).

---

## Phase 7 — Automation & Integrations

**Goal:** Make boringNotch controllable from macOS automation frameworks.

### Task 7.1: App Intents (Shortcuts)

6 intents: OpenNotch, CloseNotch, StartPomodoro, CompleteHabit, AddToShelf, ExportData. All route through `PluginManager`, no singleton access.

### Task 7.2: URL Scheme Handler

Scheme: `boringnotch://`. Routes: open, close, shelf/add, plugin actions, export. Dedicated `URLSchemeHandler` type, registered in Info.plist.

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
| 4 | Open/close feels smooth and interruptible. No "stuck" phase transitions. Content fades in progressively. |
| 4a | ✅ **Done.** Zero arch violations. All 9 items resolved. Build green + 24 tests pass. CLAUDE.md updated. |
| 5 | **MVP done:** `curl localhost:19384/api/v1/notch/state` returns valid JSON, notch open/close/toggle routes work, and WebSocket streams events. **Phase complete:** plugin/music endpoints shipped, auth + rate limiting implemented, event schema finalized, `notchctl` works. |
| 6 | Teleprompter scrolls text fed via API. DisplaySurface renders arbitrary content from `curl`. |
| 6b | AI assist actions work when available, fail gracefully when unavailable, and Teleprompter core behavior is unchanged without AI. |
| 7 | All App Intents in Shortcuts. URL scheme routes work. |
| 9 | External plugin loads from ~/Library/Application Support/boringNotch/Plugins/. |
