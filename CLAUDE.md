# boring.notch — Project Instructions

## Project Overview
macOS SwiftUI app that replaces the MacBook notch with an interactive widget system. Plugin-first architecture — every feature (music, battery, calendar, weather, shelf, webcam, notifications, clipboard) is a plugin.

## Tech Stack
- **Language:** Swift 5.9+, SwiftUI, AppKit
- **Architecture:** Plugin-first (PluginManager, NotchPlugin protocol, ServiceContainer)
- **Dependencies:** Defaults (settings), Sparkle (updates), Lottie (animations), KeyboardShortcuts
- **Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
- **Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`

## Code Standards
- **Max 300 lines per file** (hard limit). Target 200 lines.
- **No `.shared` singletons** in views or services. Use `@Environment` or init injection.
- **No direct `Defaults[.]` access** outside settings wrappers. Use `NotchSettings` protocol / `@Environment(\.bindableSettings)`.
- **`@Observable` + `@MainActor`** for all observable state. No `ObservableObject`/`@Published`.
- **Protocol-based services** injected via `PluginContext` or init parameters.
- **HUD/sneak peek requests:** Publish `SneakPeekRequestedEvent` via `PluginEventBus` — never call coordinator directly.
- **No service construction in SwiftUI views.** Views receive dependencies; they do not create them.

## SOLID Principles — Mapped to This Codebase

| Principle | Rule |
|-----------|------|
| **Single Responsibility** | One file = one responsibility. If you need an "and" to describe a file's purpose, split it. |
| **Open/Closed** | New features → new `NotchPlugin`. Never modify `PluginManager` to add feature logic. |
| **Liskov Substitution** | Every `ServiceProtocol` implementation must be fully substitutable — no `fatalError` in conformances. |
| **Interface Segregation** | Split large protocols by consumer. A plugin that only needs `play()` should not depend on `VolumeServiceProtocol.setBrightness()`. `NotchSettings` (50+ props) must be split into focused sub-protocols. |
| **Dependency Inversion** | Plugins and views depend on protocols, never concrete types. `ServiceContainer` is the only place that instantiates concrete services. |

## DDD Layer Boundaries

This app maps to DDD layers. **Layer rules are import constraints:**

| Layer | Directory | Allowed Imports | Forbidden |
|-------|-----------|-----------------|-----------|
| **Domain** | `Plugins/Core/` (protocol + state types), `Core/NotchStateMachine` | `Foundation`, `Combine`, `Swift stdlib` | SwiftUI, AppKit, Defaults, any framework |
| **Application** | `Plugins/BuiltIn/`, `PluginManager`, `ServiceContainer` | Domain + service protocols | Concrete infra types |
| **Infrastructure** | `managers/`, `Plugins/Services/` (implementations), `DefaultsNotchSettings` | Anything needed | — |
| **Presentation** | `components/`, plugin `Views/`, `ContentView` | Application layer + SwiftUI/AppKit | Direct Defaults, concrete services |

**Bounded contexts:** Each plugin (`MusicPlugin`, `ShelfPlugin`, etc.) is its own bounded context. Plugins communicate exclusively via `PluginEventBus`, never by importing each other.

**Domain purity rule:** Files in the Domain layer must compile without SwiftUI/AppKit. If they can't, they've leaked infrastructure.

**Value objects:** Use `struct` for any type that has no identity — state snapshots, events, config. Use `@Observable final class` only for entities with lifecycle and observable state.

## Known Violations — Fix in Priority Order

| Priority | File | Violation |
|----------|------|-----------|
| 🔴 | `Core/NotchContentRouter.swift` | Creates `VolumeManager(eventBus: PluginEventBus())` inline — **runtime bug**, new instances recreated every view update |
| 🔴 | `components/Shelf/Services/ShelfActionService.swift` | 849 lines — split into `ShelfActionService` / `ShelfDragDropHandler` / `ShelfShareHandler` |
| 🔴 | `managers/MusicManager.swift` | 672 lines, not properly behind `MusicServiceProtocol` |
| 🟡 | `ContentView.swift` | 543 lines — extract `NotchGestureHandler` extension + `NotchDropDelegate` |
| 🟡 | `boringNotchApp.swift` | 502 lines — extract object graph construction into `AppObjectGraph.swift` |
| 🟡 | `components/Calendar/BoringCalendar.swift` | 459 lines — split view from data formatting logic |
| 🟡 | `BoringViewCoordinator.swift` | 5 remaining `.shared` usages — Tier 3 target |
| 🟢 | Several settings views | Direct `Defaults[.]` access — replace with `@Environment(\.bindableSettings)` |

## Architecture
```
SwiftUI Views → PluginManager → NotchPlugin instances → Service Protocols → System APIs
```

| Directory | Status | Purpose |
|-----------|--------|---------|
| `Plugins/Core/` | Modern | PluginManager, NotchPlugin, PluginEventBus, PluginSettings |
| `Plugins/Services/` | Modern | ServiceContainer, 20+ service protocols + implementations |
| `Plugins/BuiltIn/` | Modern | 8 plugin implementations |
| `Core/` | Modern | NotchStateMachine, WindowCoordinator, NotchContentRouter |
| `models/` | Mixed | BoringViewModel + extracted controllers |
| `components/` | Legacy | Views migrating into plugin views |
| `managers/` | Legacy | Managers wrapping into services |

## Active Refactoring

**Branch:** `refactor/full-refactor`

**Plan:** [`docs/plans/2026-02-01-singleton-elimination-design.md`](docs/plans/2026-02-01-singleton-elimination-design.md) — tier-based, dependency-ordered migration.

Three tiers, worked **file-by-file** (all violations fixed per file in one pass):

1. **Tier 1 — Leaf files** (settings views, VolumeManager, BrightnessManager, BatteryService) — no downstream dependents, safe to migrate independently
2. **Tier 2 — Hub files** (PluginManager, ServiceContainer, NotchContentRouter) — migrate after Tier 1 consumers are clean
3. **Tier 3 — God Object** — decompose `BoringViewCoordinator` into SneakPeekService, ScreenSelectionService, NavigationState

**Key file to eliminate:** `BoringViewCoordinator.swift` — singleton used by 17 files. See plan for exact dependency graph and PR sequence.

## Skills

Use these skills (invoke via Skill tool) when working on this project:

| Skill | When |
|-------|------|
| `superpowers:brainstorming` | Before any design decision or new extraction |
| `superpowers:writing-plans` | When scoping multi-step refactoring work |
| `superpowers:executing-plans` | When implementing from the plan doc |
| `superpowers:subagent-driven-development` | For parallel refactoring tasks |
| `superpowers:systematic-debugging` | When a build breaks or tests fail |
| `superpowers:verification-before-completion` | Before claiming any task is done |
| `superpowers:requesting-code-review` | After completing a tier or major task |

## Key Files
- `docs/plans/2026-02-01-singleton-elimination-design.md` — active implementation plan
- `PLAN.md` — high-level overview (phases 6-8 superseded by plan above)
- `.ai-docs/decisions/refactoring-strategy.md` — architectural decisions
- `boringNotch/BoringViewCoordinator.swift` — main singleton to eliminate
- `boringNotch/Plugins/Core/PluginManager.swift` — central plugin orchestrator
- `boringNotch/Plugins/Services/ServiceContainer.swift` — DI container

## Build & Verify
Always build after changes. Don't commit without a green build.
