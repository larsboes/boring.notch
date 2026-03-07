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
**Branch sync:** `developer` = working branch (`refactor/singleton-elimination-tier3`), `main` may differ

| Phase | Status | Summary |
|-------|--------|---------|
| 1, 1b, 2, 3, 5, 6, 6b, 7, 8 | ✅ Shipped | Core plugins, API Hardening, AI Assist, Automation, Battery & Export |
| 4 — Animation + Arch Debt | **Active** | 15+ items done. Remaining: spring tuning, album art morph, gesture-driven open. |
| 9 — Third-Party Distribution | Planned | .boringplugin bundle format |

**Latest architecture hardening commits:**
- `d277bd4` — snapshot before cleanup
- `0d7bd2b` — DI tightening + unsafe force-unwrap removal + singleton elimination work
- `89661d5` — project build wiring repair for LocalAPI/private sources
- `0b881d7` — architecture gate update for split settings files + core force-unwrap checks

---

## ✅ Shipped Work

| Task | Phase | Description |
|:-----|:------|:------------|
| 4.1 | Animation | Phase timing tuned — open 400→350ms, close 350→300ms for snappier feel. |
| 4.2 | Animation | Staggered header fade with blur — elements reveal sequentially during open. |
| 4.3 | Animation | Stagger interval widened 0.03→0.06s, shadow late-onset via `pow(2.5)`, border linger via `sqrt` curve. |
| 4.4 | Animation | Content choreography (open) — `ContentRevealModifier` drives continuous `contentProgress` environment key from 0→1. |
| 4.5 | Animation | Content choreography (close) — reverse path, `contentProgress` 1→0, automatic via modifier. |
| 4.6 | Animation | Replaced all `Task.sleep` phase transitions with `withAnimation` completion handlers — no more timing drift. |
| 4.7 | Arch Debt | `DefaultsNotchSettings` split from 457 lines into 5 ISP-compliant extension files. |
| 4.8 | Arch Debt | Duplicate stub files deleted across codebase. |
| 4.9 | Arch Debt | `NotchStateMachine` → `NotchAnimationStateProviding` protocol extraction for testability. |
| 4.10 | Arch Debt | All direct `Defaults[.]` reads routed through settings sub-protocols — no more raw UserDefaults in business logic. |
| 4.11 | Concurrency | `@MainActor` added to `NotificationCenterManager` — fixes implicit Sendable violations. |
| 4.12 | DI | `QuickLookService` injected via `QuickLookServiceProtocol` — was concrete dependency. |
| 4.13 | Docs | CLAUDE.md DDD table updated: `Plugins/Core/` reclassified as Application layer. |
| 4.14 | Cleanup | `sneakPeek` → `SneakPeek` case rename for Swift naming conventions. |
| 4.15 | Safety | Removed force-unwrap usage in core runtime UI paths (`ContentView`, `ContentView+Appearance`) and switched to safe optional handling. |
| 4.16 | DI | View layer no longer constructs fallback music services; `ContentView` now consumes injected `vm.musicService`. |
| 4.17 | DI / SOLID | `NotchServiceProvider` now exposes protocol-typed notes/clipboard/bluetooth services instead of concrete managers; consumers updated accordingly. |
| 4.18 | Architecture | Removed `NotchStateMachine.shared` and reduced singleton-default constructor usage in coordinator/view-model/service paths. |
| 4.19 | Build | Repaired Xcode target source wiring for LocalAPI/private files to keep build reproducible and green. |
| 4.20 | CI | Updated architecture check script allowlist for split settings files and added force-unwrap guardrails in core runtime paths. |
| 4.21 | Animation | Spring curve refinement — open: 0.32/0.92, close: 0.26/0.97, interactive: 0.20/0.94. Apple DI confidence. |
| 4.22 | Animation | Album art ghost fix — matchedGeometryEffect suppressed during transitions + lighting effect gated behind phase. |
| 4.23 | Animation | Shell-first content timeline — contentProgress delayed to 30%, ContentRevealModifier tightened, stagger cascade faster. |
| 4.24 | UX | Header controls gated on `phase == .open` — no accidental taps during transition. |
| 5.1 | API | **Loopback binding** — `LocalAPIServer` now binds `127.0.0.1` only via `NWParameters.requiredLocalEndpoint`. |
| 5.2 | API | **Dynamic routing** — `APIRouteRegistrar` protocol (own file) enables plugins to register/unregister REST routes at runtime. Path params (`/plugins/{id}`) with proper 404 vs 405. |
| 5.3 | API | **Auth middleware** — Keychain-backed Bearer token in `APIAuthMiddleware` (`@unchecked Sendable`, `NSLock`). Denies on keychain failure (secure default). Enforced on all POST endpoints. |
| 5.4 | API | **Rate limiter** — `APIRateLimiter` (own file), sliding window 10 req/s per client. Periodic cleanup every 60s evicts stale clients — prevents unbounded memory growth. |
| 5.5 | API | **CLI companion** — `notchctl` shell script in `scripts/` wrapping REST API (`open`, `close`, `display`, `music`, `teleprompter`). |
| 5.6 | API | **REST endpoints** — full coverage: notch state/open/close/toggle, plugin list/detail/toggle, music now-playing/play-pause/next/previous. All plugin accesses wrapped in `MainActor.run`. |
| 5.7 | API | **Event enrichment** — WebSocket payloads now include event-specific data (track title/artist/album, battery level/charging, notch phase) instead of generic metadata. |
| 6.1 | Plugin | **TeleprompterPlugin** — camera-adjacent script scrolling. 6 API endpoints (load/start/pause/stop/state/ai-assist). Timer only fires when `isScrolling == true` (no idle 60fps overhead). `didSet` observer manages lifecycle. |
| 6.2 | Plugin | **DisplaySurfacePlugin** — generic ambient display accepting text/progress/markdown via API. TTL support with cancellable `Task`. 3 endpoints (text/progress/clear). |
| 6.3 | Infra | **Plugin route registration** — `apiRouteRegistrar` exposed on `NotchServiceProvider`. Plugins register routes in `activate()`, unregister in `deactivate()`. |
| 6b.1 | AI | **3-tier AI stack** — `AIProvider` (transport, `Sendable`) → `AITextGenerationService` (domain protocol, `@MainActor`) → `ProviderBackedAIService` / `NoAITextGenerationService`. |
| 6b.2 | AI | **Deterministic fallback** — `NoAITextGenerationService` throws clear errors with actionable install instructions. Default when AI disabled or no provider. |
| 6b.3 | AI | **OllamaProvider** — local LLM at `127.0.0.1:11434` with health check (`GET /api/tags`, 2s timeout), typed errors, 30s generation timeout. |
| 6b.4 | AI | **AIManager DI** — no singleton access. `isEnabled` injected as closure from settings. Exposes `textGeneration: any AITextGenerationService`. |
| 6b.5 | AI | **Domain methods** — `rewrite(_:style:)` (4 styles), `summarize(_:)`, `section(_:)`, `draftIntro(topic:durationSeconds:)`. Prompt engineering encapsulated in `ProviderBackedAIService`. |
| 6b.6 | AI | **Teleprompter AI** — type-safe `TeleprompterAIAction` enum (refine/summarize/draft-intro). `DecodingError` returns 400 with valid options. |
| 6b.7 | AI | **Settings DI** — `isAIEnabled` added to `GeneralAppSettings` protocol + `DefaultsKeys.enableAI` + `MockNotchSettings`. No singleton reads. |
| 6b.8 | AI | **Service protocol** — `NotchServiceProvider.ai` typed as `any AITextGenerationService` (not concrete `AIManager`). `ServiceContainer` wires via `AIManager.textGeneration`. |
| 7.1 | Automation | **App Intents** — `OpenNotchIntent` + `CloseNotchIntent` routed through `NotificationCenter` bridge to `BoringViewModel`. No singleton coupling. |
| 7.2 | Automation | **URL scheme** — `boringnotch://` open/close/toggle/plugins. Toggle checks `vm.notchState` for correct dispatch. Registered via `NSAppleEventManager` in AppDelegate. |
| 7.3 | Automation | **Intent bridge** — `BoringViewModel.setupIntentObservers()` observes `.openNotchIntent` / `.closeNotchIntent` on main queue with `[weak self]`. |

---

## Phase 4 — Animation Polish + Architecture Debt (Active)

**Goal:** Dynamic Island-quality open/close transitions + clean architecture.

**Verified:** Zero files >300 lines, zero Defaults leaks, build green, 28 tests passing.

### Task 14: Spring curve refinement

**Status:** ✅ Complete

| Animation | Before | After | Change |
|-----------|--------|-------|--------|
| `open` | response: 0.38, damping: 0.82 | response: 0.32, damping: 0.92 | Less bounce, more confident — Apple DI feel |
| `close` | response: 0.35, damping: 0.92 | response: 0.26, damping: 0.97 | Quicker, near-critically damped retraction |
| `interactive` | response: 0.30, damping: 0.86 | response: 0.20, damping: 0.94 | Tight tracking, zero wobble |
| `staggered` | response: 0.32, damping: 0.86, delay: 0.06s | response: 0.30, damping: 0.88, delay: 0.05s | Tighter cascade |

### Task 19: Matched album art transition

**Status:** Partially implemented — matchedGeometryEffect wired but suppressed during transitions

`matchedGeometryEffect(id: "albumArt")` is connected on both `MusicLiveActivity` (closed) and `PluginAlbumArtView` (open). However, during `opening`/`closing` phases the effect is suppressed (namespace set to nil) because the container's spring animation conflicts with the geometry morph, causing stretch/ghost artifacts. Full morph will be re-enabled with Task 15 (gesture-driven progressive open) where the transition is scrubbed rather than spring-animated.

### Task 21: Animation artifact fixes + shell-first timeline

**Status:** ✅ Complete

**Album art ghost fix:**
- `matchedGeometryEffect` suppressed during transitions (both closed and open art views) — prevents spring-vs-morph conflict that caused stretch/jump.
- `albumArtBackground` lighting effect (blur/rotate/scale glow) suppressed during transitions — eliminates ghost decoration artifacts.

**Shell-first content timeline:**
- `contentProgress` starts at 30% of shell expansion (was 20%) — visible "shell leads, content follows" effect.
- `ContentRevealModifier` tightened: scale 0.94 (was 0.92), offset -3 (was -4), blur 8 (was 12). Subtler, more confident reveal.
- Stagger step reduced to 0.06 (was 0.08) for quicker cascade.

**Header/action gating:**
- Controls gated on `phase == .open` (fires after animation completes) instead of `notchState == .open` (fires at animation start). Prevents accidental taps and visual flicker during transition.

### Task 15: Gesture-driven progressive open (Future)

**Status:** Deferred — needs design

Replace fire-and-forget animations with continuous gesture-driven expansion. Notch height/width maps 1:1 to gesture translation — interruptible and scrubbable. Substantial refactor of `BoringViewModel+OpenClose`. Defer until Tasks 16-20 shipped.

---

## Phase 5 — Local API Server ✅

```
External clients (curl, Raycast, scripts, browser ext)
        │
        ▼
  LocalAPIServer (Network.framework, port 19384, loopback-only)
        │
        ├── REST routes → PluginManager / ServiceContainer
        │       (Bearer token auth on POST, rate limited 10 req/s)
        │
        └── WebSocket /events → PluginEventBus (enriched payloads)
```

**Endpoints:**
```
GET  /api/v1/notch/state              POST /api/v1/notch/open|close|toggle
GET  /api/v1/plugins                  GET  /api/v1/plugins/{id}
POST /api/v1/plugins/{id}/toggle
GET  /api/v1/music/now-playing        POST /api/v1/music/play-pause|next|previous
WS   /api/v1/events                   → notch.opened, music.changed, system.batteryChanged, ...
```

**CLI:** `notchctl open|close|display|music|teleprompter` — shell script in `scripts/`.

---

## Phase 6 — API-Powered Plugins ✅

### TeleprompterPlugin — `Plugins/BuiltIn/TeleprompterPlugin/`

Camera-adjacent script scrolling for natural eye contact during video calls and presentations.

**Endpoints (self-registered on activate):**
```
POST /api/v1/teleprompter/load        → { text, speed?, fontSize? }
POST /api/v1/teleprompter/start|pause|stop
GET  /api/v1/teleprompter/state       → { position, isScrolling, text }
POST /api/v1/teleprompter/ai-assist   → { action: "refine" | "summarize" | "draft-intro" }
```

**Display:** `.high` when scrolling, `.normal` when paused, `nil` when empty.

### DisplaySurfacePlugin — `Plugins/BuiltIn/DisplaySurfacePlugin/`

Generic "dumb terminal" — renders whatever the API tells it to. No built-in logic.

**Endpoints (self-registered on activate):**
```
POST /api/v1/display/text             → { text, ttl? }
POST /api/v1/display/progress         → { label, value, ttl? }
POST /api/v1/display/clear
```

**Content types:** `.text`, `.markdown`, `.progress(label, value)`, `.keyValue([(String, String)])`, `.clear`

**Example integrations:**

| Script | Endpoint | Notch shows |
|--------|----------|-------------|
| CI watcher | `POST /display/progress {"label": "Build", "value": 0.73}` | Progress bar |
| Deploy script | `POST /display/text {"text": "Deployed v2.4.1 ✓", "ttl": 10}` | Temporary status |
| Meeting summarizer | `POST /display/text {"text": "Key: budget approved"}` | Real-time notes |

---

## Phase 6b — On-Device AI Assist ✅

```
Plugins  →  AITextGenerationService (domain: rewrite/summarize/section/draftIntro)
                    │
                    ├── ProviderBackedAIService (prompt engineering layer)
                    └── NoAITextGenerationService (deterministic fallback)
                            │
                    AIProvider (transport: generate)
                            ├── OllamaProvider (127.0.0.1:11434)
                            └── future: FoundationModelsProvider (#available macOS 26)
```

**Hard rule:** AI is assistive only. No core plugin workflow depends on AI availability.

**DI:** `NotchServiceProvider.ai → any AITextGenerationService`. `ServiceContainer` wires via `AIManager(isEnabled: { settings.isAIEnabled }).textGeneration`. No singletons.

### Future: Apple Foundation Models (macOS 26+)

When available: create `FoundationModelsProvider: AIProvider` gated behind `#available(macOS 26, *)`, register in `AIManager` alongside Ollama, auto-select (Foundation Models preferred — zero config). No plugin code changes needed.

### Remaining AI plugin opportunities

- **DisplaySurface:** summarize long pushed content into notch-safe cards
- **Notifications:** merge notification bursts into "what matters now" digests
- **Clipboard:** rewrite/clean copied text, extract action items
- **Calendar:** compact "next up" meeting briefs

---

## Phase 7 — Automation & Integrations ✅

**App Intents:** `OpenNotchIntent`, `CloseNotchIntent` — Shortcuts-compatible, NotificationCenter bridge.
**URL Scheme:** `boringnotch://open|close|toggle|plugins?id=...` — registered via `NSAppleEventManager`.
**Bridge:** `BoringViewModel.setupIntentObservers()` on main queue with `[weak self]`.

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
| 4a | ✅ **Done.** Zero arch violations. All 9 items resolved. Build green + 28 tests pass. CLAUDE.md updated. |
| 5 | ✅ **Done.** `curl localhost:19384/api/v1/notch/state` returns valid JSON. All REST endpoints shipped (notch, plugins, music). Auth + rate limiting enforced. WebSocket streams enriched events. `notchctl` works. |
| 6 | ✅ **Done.** Teleprompter scrolls API-fed text. DisplaySurface renders arbitrary content from `curl`. |
| 6b | ✅ **Done.** 3-tier AI architecture. Domain protocol with Ollama provider + deterministic fallback. No singleton access. Prompt engineering encapsulated. Foundation Models path scaffolded for macOS 26+. |
| 7 | ✅ **Done.** App Intents in Shortcuts. URL scheme routes work (including toggle). |
| 9 | External plugin loads from ~/Library/Application Support/boringNotch/Plugins/. |
