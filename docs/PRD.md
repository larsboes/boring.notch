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
| 1, 1b, 2, 3, 5, 6, 6b, 7 | ✅ Shipped | Core plugins, API Hardening, AI Assist, Automation, Battery & Export |
| 4 — Animation + Arch Debt | **Active** | 15+ items done. Remaining: spring tuning, album art morph, gesture-driven open. |
| 9 — Third-Party Distribution | Planned | .boringplugin bundle format |
| 10 — Teleprompter Pro | Planned | Voice-driven scrolling, countdown, enhanced editor, display polish, keyboard shortcuts |
| 11 — Foundation Models | Planned | On-device AI via Apple FoundationModels (macOS 26+), streaming, structured generation |

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
| 4.25 | Arch Debt | Removed unused `SoundService.shared` singleton (dead code). |
| 4.26 | Animation | HelloAnimation `Task.sleep(3.0)` replaced with `withAnimation` completion handler — eliminates timing drift on startup snake. |
| 4.27 | Domain Purity | Removed `import SwiftUI` from 5 Core/ domain files (`NotchStateMachine`, `NotchSettingsSubProtocols`, `MockNotchSettings`, `DefaultsNotchSettings`, `NavigationState`) — now compile with only `Foundation`/`Observation`/`Defaults`. |
| 4.28 | Docs | Fixed 5 doc discrepancies: ServiceContainer path in ARCHITECTURE.md, plugin registration location in PLUGIN_DEVELOPMENT.md, phantom Phase 8 in PRD, plugin count (8→12), BoringViewCoordinator status (legacy→active). Updated CLAUDE.md layer boundaries to distinguish domain vs coordinator files in Core/. |
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
| 6b.3 | AI | **OllamaProvider** — local LLM at `127.0.0.1:11434` with health check (`GET /api/tags`, 2s timeout), typed errors, 30s generation timeout. *(Phase 11: demoted to opt-in Advanced provider)* |
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
                            ├── FoundationModelsProvider (#available macOS 26) — PRIMARY
                            └── OllamaProvider (opt-in, Advanced settings only)
```

**Hard rule:** AI is assistive only. No core plugin workflow depends on AI availability.

**DI:** `NotchServiceProvider.ai → any AITextGenerationService`. `ServiceContainer` wires via `AIManager(isEnabled: { settings.isAIEnabled }).textGeneration`. No singletons.

### AI Provider Strategy

- **Primary:** Apple Foundation Models (macOS 26+). On-device, zero config, zero install, fully private. Covers the teleprompter sweet spot (summarization, rewriting, extraction).
- **Optional/Advanced:** Ollama for power users who want larger/specialized models. Hidden behind "Advanced AI Settings" toggle. Not registered unless explicitly enabled.
- **Fallback:** `NoAITextGenerationService` — clean degradation. On macOS <26 or unsupported hardware, AI features simply don't appear in the UI. No "install Ollama" messaging.

**Migration:** `OllamaProvider` to be removed from default `AIManager.init()` registration. Foundation Models becomes the sole default provider. See Phase 11 for implementation details.

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

## Phase 10 — Teleprompter Pro (Moody-Class Upgrade)

**Goal:** Transform the basic teleprompter into a professional-grade, voice-aware prompter with Apple Foundation Models integration. Competitive reference: [Moody](https://moody.mjarosz.com/) — the notch teleprompter benchmark.

**Design Principle:** The notch is the most camera-adjacent display surface on any MacBook. A teleprompter here is *the* killer feature — but only if it's polished enough that creators actually use it daily.

### Current State Assessment

The existing teleprompter (Phase 6) is functional but bare-bones:
- Timer-driven scroll at fixed px/s
- Basic `TextEditor` for script input
- Play/pause/stop + speed slider (10–80 px/s)
- Paste from clipboard
- AI assist (refine/summarize/draft-intro) via Ollama only
- Closed view shows one line of text beside the notch

**What's missing for professional use:** voice-driven scrolling, visual feedback, countdown, keyboard controls, calibration, rich editing, and on-device AI that works without installing Ollama.

### 10.1 — Voice-Driven Scrolling ("Flow Mode")

**Status:** Planned

Use `AVAudioEngine` + `SFSpeechRecognizer` to match scroll speed to speaking pace. When the speaker pauses, scrolling pauses. When they speed up, scrolling accelerates.

**Implementation:**
- `VoiceScrollEngine` — new file in `TeleprompterPlugin/`
- Taps system microphone via `AVAudioEngine.inputNode`
- Uses `SFSpeechRecognizer` for real-time speech-to-text
- Matches recognized words against script text to determine position
- Falls back to audio energy level (RMS) when speech recognition unavailable
- Adjustable microphone sensitivity slider in settings
- Permission request: microphone access (graceful degradation if denied)

**Algorithm:**
```
1. Continuous speech recognition → word stream
2. Fuzzy-match recognized words against script text (Levenshtein / sliding window)
3. When match found → snap scroll position to matched word's Y offset
4. When no speech detected for >1s → pause scrolling
5. Fallback: if speech recognition off, use audio RMS level to modulate speed
```

**Key constraint:** Flow Mode is *optional*. Manual scroll (current timer-based) remains the default. User toggles between modes.

### 10.2 — Voice Visual Feedback

**Status:** Planned

Visual beam/glow emanating from the notch that responds to microphone input level. Helps speakers monitor their volume without looking away from camera.

**Implementation:**
- `VoiceBeamView` — SwiftUI view overlaying the notch area
- Reads audio level from `VoiceScrollEngine`'s tap (shared `AVAudioEngine`)
- Renders as a radial gradient / arc that scales with RMS amplitude
- Color: subtle blue-purple gradient (matches notch aesthetic)
- Configurable: on/off, opacity, color

### 10.3 — Countdown Timer

**Status:** Planned

3-2-1 countdown before scrolling begins. Gives the speaker time to settle, check camera framing, take a breath.

**Implementation:**
- `CountdownOverlayView` displayed in closed notch when "Start" is pressed
- Large, cinematic numbers (SF Rounded, heavy weight) with scale+fade animation
- Configurable duration: 3s (default), 5s, or off
- After countdown completes → scrolling begins automatically
- Cancel by clicking notch during countdown

### 10.4 — Built-In Script Editor (Enhanced)

**Status:** Planned

Replace the minimal `TextEditor` with a proper script editing experience.

**Features:**
- Larger editing area in expanded panel (full available height)
- Markdown-aware rendering: `## Section` headers render as visual dividers
- Word count + estimated reading time display (based on current scroll speed)
- Section navigation: click section headers to jump
- Undo/redo support
- Import from file (`.txt`, `.md`, `.rtf`) via drag-and-drop or file picker
- Auto-save script to `PluginSettings` (persists across app restarts)
- Multiple scripts: save/load named scripts

### 10.5 — Scroll Speed Calibration

**Status:** Planned

Guided calibration flow where the user reads a sample text at their natural pace. The system measures their reading speed and sets the default accordingly.

**Implementation:**
- Calibration wizard accessible from settings
- Shows sample paragraph in the notch area
- User reads aloud (or reads silently and taps when done)
- Calculates words-per-minute → maps to px/s scroll speed
- Stores calibrated speed as default
- Preview: real-time scroll speed preview at top of calibration screen (like Moody)

### 10.6 — Hover-to-Pause

**Status:** Planned

Moving the cursor over the teleprompter text instantly pauses scrolling. Moving cursor away resumes. Zero-friction control for quick script checks.

**Implementation:**
- `.onHover` modifier on `TeleprompterClosedView`
- Sets `state.isScrolling = false` on hover enter, `true` on exit
- Only active when teleprompter was already scrolling (don't start scrolling on hover exit if it wasn't running)
- Visual indicator: subtle pause icon appears on hover

### 10.7 — Keyboard Shortcuts

**Status:** Planned

Professional prompters need hands-free or keyboard-only control.

| Shortcut | Action |
|----------|--------|
| `Space` (when teleprompter active) | Play/Pause toggle |
| `↑` / `↓` | Manual scroll (fine-grained) |
| `⌘↑` / `⌘↓` | Increase/decrease speed |
| `⌘⇧T` | Open teleprompter panel |
| `Escape` | Stop and reset |
| `⌘R` | Restart from beginning |

**Implementation:** Register via `KeyboardShortcuts` framework (already a dependency). Only active when teleprompter has loaded text.

### 10.8 — Display Customization

**Status:** Planned

- Font size slider (already exists, expand range: 10–40pt)
- Text color picker (white, yellow, green — common prompter colors)
- Background opacity (0–100% behind text for readability)
- Mirror mode (horizontally flip text — for physical teleprompter setups with beam splitters)
- Line highlight: current line gets full opacity, surrounding lines fade (karaoke-style)
- Margin/padding controls for text positioning

### 10.9 — Improved Closed-Notch Display

**Status:** Planned

The current closed view shows one line of truncated text on one side. This needs to be a proper reading surface.

**Improvements:**
- Text renders *centered under the camera* (the whole point of notch-prompting)
- Show 2–3 lines: current line bold/bright, next lines progressively dimmer
- Smooth per-pixel scroll (not line-snapping)
- Progress indicator: subtle bar showing position in script (0–100%)
- Current section title shown if script uses `##` headers
- Elapsed time / remaining time (small, non-distracting)

### 10.10 — Screen Sharing Safety

**Status:** Planned

The teleprompter text should be invisible during screen sharing — the speaker sees it, but their audience doesn't.

**Implementation:**
- Use `NSWindow.sharingType = .none` on the teleprompter overlay window
- This excludes the window from screen capture, screenshots, and screen sharing
- Toggle in settings: "Hide from screen sharing" (default: on)
- Alternative: detect active screen sharing via `CGDisplayStream` and auto-hide

---

## Phase 11 — Apple Foundation Models Integration

**Goal:** First-class on-device AI via Apple's `FoundationModels` framework (macOS 26+). Zero config, zero external dependencies, fully private.

**Why this matters:** The current AI stack requires Ollama (manual install, ~4GB download, must be running). Foundation Models is built into macOS 26 — it just works. This makes AI features accessible to 100% of users on supported hardware, not just developers who know what Ollama is.

### Architecture

The existing 3-tier AI stack (`AIProvider` → `AITextGenerationService` → `ProviderBackedAIService`) was designed for this. `FoundationModelsProvider` becomes the sole default provider.

```
AIManager
├── FoundationModelsProvider  ← PRIMARY (macOS 26+, zero config, on-device)
├── OllamaProvider            ← OPT-IN (Advanced settings toggle, power users only)
└── NoAITextGenerationService ← FALLBACK (macOS <26 or unsupported hardware)

Default: Foundation Models (if macOS 26+) > NoAI
Advanced: User explicitly enables Ollama → Ollama (if running) > Foundation Models > NoAI
```

### 11.1 — FoundationModelsProvider

**Status:** Planned

```swift
// Gated behind #available(macOS 26, *)
@available(macOS 26, *)
struct FoundationModelsProvider: AIProvider {
    let id = "foundation-models"
    let name = "Apple Intelligence"

    var isAvailable: Bool {
        get async {
            SystemLanguageModel.default.availability == .available
        }
    }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
```

**Key decisions:**
- New `LanguageModelSession` per call (stateless provider, session management is caller's job)
- Map `AIGenerationConfig.temperature` etc. where possible (Foundation Models may have limited knobs)
- Availability check via `SystemLanguageModel.default.availability`
- Errors: map `LanguageModelSession` errors to `AIError` cases

### 11.2 — Streaming Support

**Status:** Planned

The current `AIProvider.generate()` returns a complete `String`. Add streaming variant for responsive UX.

```swift
protocol AIProvider: Sendable {
    // ... existing ...
    func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error>
}
```

**Foundation Models streaming:**
```swift
func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            let stream = session.streamResponse(to: prompt)
            for try await partial in stream {
                continuation.yield(partial.content ?? "")
            }
            continuation.finish()
        }
    }
}
```

**Impact on teleprompter:** AI-assisted rewriting shows text appearing progressively instead of a loading spinner → results dialog.

### 11.3 — Structured Generation for Teleprompter

**Status:** Planned

Use `@Generable` for type-safe AI outputs instead of parsing raw text.

```swift
@available(macOS 26, *)
@Generable
struct TeleprompterScript {
    @Guide(description: "The rewritten script text, natural spoken language")
    var text: String

    @Guide(description: "Estimated reading time in seconds")
    var estimatedDurationSeconds: Int

    @Guide(description: "Section markers with timestamps", .maximumCount(10))
    var sections: [ScriptSection]
}

@available(macOS 26, *)
@Generable
struct ScriptSection {
    var title: String
    var startWord: Int
}
```

**Benefits:**
- Guaranteed valid output structure (no parsing failures)
- Section markers auto-generated → navigation in editor for free
- Duration estimate → progress bar accuracy

### 11.4 — Expanded AI Actions

**Status:** Planned

Beyond the current refine/summarize/draft-intro, add:

| Action | Description | Use Case |
|--------|-------------|----------|
| `expandBullets` | Expand bullet points into full spoken paragraphs | Turning notes into a script |
| `simplify` | Reduce reading level, shorter sentences | Accessibility, non-native speakers |
| `addPauses` | Insert `[PAUSE]` markers at natural break points | Pacing guidance |
| `translateStyle` | Convert between formal/casual/technical | Audience adaptation |
| `timeToTarget` | Rewrite to hit a target duration (e.g., "make this a 2-minute script") | Time-constrained presentations |

**Implementation:** New cases in `TeleprompterAIAction` enum + corresponding prompts in `ProviderBackedAIService`. Foundation Models handles these well since they're summarization/extraction tasks (its sweet spot per Apple's guidance — not world knowledge).

### 11.5 — Smart Instructions for Foundation Models

**Status:** Planned

Use `LanguageModelSession(instructions:)` for teleprompter-specific system prompts:

```swift
let session = LanguageModelSession(
    instructions: """
    You are a teleprompter script assistant. Your outputs will be read aloud \
    on camera. Write in natural spoken language — short sentences, clear \
    transitions, no jargon unless the speaker's context requires it. \
    Never include stage directions or formatting instructions.
    """
)
```

### 11.6 — Provider Registration Overhaul

**Status:** Planned

Replace current Ollama-default `AIManager.init()` with Foundation Models-first strategy:

```swift
init(isEnabled: @escaping () -> Bool = { true }, ollamaEnabled: @escaping () -> Bool = { false }) {
    self.isEnabledProvider = isEnabled
    self.ollamaEnabledProvider = ollamaEnabled

    // Primary: Foundation Models (macOS 26+, zero config)
    if #available(macOS 26, *) {
        registerProvider(FoundationModelsProvider())
        activeProviderId = "foundation-models"
    }

    // Ollama ONLY if user explicitly opts in via Advanced settings
    // Not registered by default — no "install Ollama" messaging anywhere
}

/// Called when user enables Ollama in Advanced AI Settings
func enableOllama(model: String = "llama3", host: String = "http://127.0.0.1:11434") {
    registerProvider(OllamaProvider(model: model, host: host))
    // Ollama takes priority when explicitly enabled (user wants bigger models)
    activeProviderId = "ollama"
}

func disableOllama() {
    providers.removeValue(forKey: "ollama")
    // Fall back to Foundation Models or NoAI
    if #available(macOS 26, *) {
        activeProviderId = "foundation-models"
    } else {
        activeProviderId = nil
    }
}
```

**Feature gating:** On macOS <26 without Ollama enabled, AI action buttons simply don't render. No error states, no "upgrade macOS" messaging — the feature just isn't there. Clean absence > broken presence.

**Availability resilience:** Foundation Models may report `.available` at init but fail later (model downloading, etc.). The `generate()` call catches errors and surfaces them per-request — no automatic fallback to Ollama unless user explicitly configured it.

### 11.7 — AI Settings UI

**Status:** Planned

**Main AI Settings (visible to all users on macOS 26+):**
- AI enable/disable toggle
- AI availability indicator (green dot = Foundation Models ready)
- "Test AI" button — sends a sample prompt and shows response

**Advanced AI Settings (collapsed/hidden section):**
- "Use custom AI provider (Ollama)" toggle — off by default
- When enabled:
  - Ollama model name (default: `llama3`)
  - Ollama host (default: `127.0.0.1:11434`)
  - Connection status indicator
  - "Ollama takes priority over Apple Intelligence when enabled" note
- Link to Ollama docs for installation

**On macOS <26:** AI settings section shows "AI features require macOS 26 or later" with the Advanced section still available for Ollama opt-in.

---

## Phase 10/11 Implementation Order

Prioritized by user impact and dependency chain:

| Priority | Task | Depends On | Impact |
|----------|------|------------|--------|
| **P0** | 10.3 Countdown timer | — | Quick win, high polish |
| **P0** | 10.7 Keyboard shortcuts | — | Essential for hands-free use |
| **P0** | 10.9 Improved closed display | — | Core reading experience |
| **P1** | 10.6 Hover-to-pause | — | Zero-friction control |
| **P1** | 10.4 Enhanced editor | — | Content creation flow |
| **P1** | 10.8 Display customization | — | Personal preference |
| **P1** | 10.10 Screen sharing safety | — | Professional use case |
| **P1** | 11.1 FoundationModelsProvider | — | Zero-config AI for all users |
| **P1** | 11.6 Auto-select provider | 11.1 | Seamless provider switching |
| **P2** | 10.1 Voice-driven scrolling | AVAudioEngine, SFSpeechRecognizer | Flagship differentiator |
| **P2** | 10.2 Voice visual feedback | 10.1 (shared audio engine) | Polish on top of voice |
| **P2** | 10.5 Scroll speed calibration | — | Nice-to-have |
| **P2** | 11.2 Streaming support | 11.1 | Better AI UX |
| **P2** | 11.3 Structured generation | 11.1 | Better AI output quality |
| **P3** | 11.4 Expanded AI actions | 11.1 | More AI capabilities |
| **P3** | 11.5 Smart instructions | 11.1 | Better AI context |
| **P3** | 11.7 AI settings UI | 11.1 | Power user config |

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
| 6b | ✅ **Done.** 3-tier AI architecture. Domain protocol with deterministic fallback. No singleton access. Prompt engineering encapsulated. *(Phase 11: Ollama demoted to opt-in, Foundation Models becomes primary.)* |
| 7 | ✅ **Done.** App Intents in Shortcuts. URL scheme routes work (including toggle). |
| 9 | External plugin loads from ~/Library/Application Support/boringNotch/Plugins/. |
| 10 | Teleprompter has voice-driven scrolling, countdown timer, keyboard shortcuts, improved closed display with 2–3 lines centered under camera, hover-to-pause, screen sharing safety. Creator-daily-driver quality. |
| 11 | `FoundationModelsProvider` is sole default provider on macOS 26+. AI features work with zero external dependencies. Ollama available as opt-in Advanced option only. Streaming AI responses in teleprompter UI. Structured generation via `@Generable`. On macOS <26: AI features cleanly absent (no broken states). |
