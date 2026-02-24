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
- **No `.shared` singletons** in views or services. Use `@Environment` or init injection. Acceptable exceptions: `NSWorkspace.shared`, `NSApplication.shared`, `URLSession.shared`, `URLCache.shared`, `XPCHelperClient.shared`, `FullScreenMonitor.shared`, `QLThumbnailGenerator.shared`, `QLPreviewPanel.shared()`, `NSScreenUUIDCache.shared`, `SkyLightOperator.shared`, `DefaultsNotchSettings.shared` (settings injection root only).
- **No direct `Defaults[.]` access** outside `DefaultsNotchSettings.swift`. Use `NotchSettings` protocol / `@Environment(\.bindableSettings)`.
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
| **Interface Segregation** | Split large protocols by consumer. A plugin that only needs `play()` should not depend on `VolumeServiceProtocol.setBrightness()`. |
| **Dependency Inversion** | Plugins and views depend on protocols, never concrete types. `ServiceContainer` is the only place that instantiates concrete services. |

## DDD Layer Boundaries

Layer rules are import constraints:

| Layer | Directory | Allowed Imports | Forbidden |
|-------|-----------|-----------------|-----------|
| **Domain** | `Plugins/Core/`, `Core/NotchStateMachine` | `Foundation`, `Combine`, `Swift stdlib` | SwiftUI, AppKit, Defaults, any framework |
| **Application** | `Plugins/BuiltIn/`, `PluginManager`, `ServiceContainer` | Domain + service protocols | Concrete infra types |
| **Infrastructure** | `managers/`, `Plugins/Services/` (implementations), `DefaultsNotchSettings` | Anything needed | — |
| **Presentation** | `components/`, plugin `Views/`, `ContentView` | Application layer + SwiftUI/AppKit | Direct Defaults, concrete services |

**Bounded contexts:** Each plugin is its own bounded context. Plugins communicate exclusively via `PluginEventBus`, never by importing each other.

**Domain purity rule:** Files in the Domain layer must compile without SwiftUI/AppKit. If they can't, they've leaked infrastructure.

**Value objects:** Use `struct` for types with no identity. Use `@Observable final class` only for entities with lifecycle and observable state.

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

## Key Files
- `docs/PRD.md` — active implementation plan (Phase 1–7) + migration status
- `docs/STATE_MANAGEMENT_ANALYSIS.md` — hover state redesign spec (referenced by PRD Task 9)
- `docs/ARCHITECTURE.md` — architecture reference
- `docs/PLUGIN_DEVELOPMENT.md` — plugin development guide
- `boringNotch/AppObjectGraph.swift` — DI root; constructs all services and coordinators
- `boringNotch/Plugins/Core/PluginManager.swift` — central plugin orchestrator
- `boringNotch/Plugins/Services/ServiceContainer.swift` — DI container
- `boringNotch/BoringViewCoordinator.swift` — coordinator being phased out (see PRD Task 8)
- `boringNotch/Core/NotchStateMachine.swift` — pure, tested, stable state machine

## Files to Not Touch
- `boringNotch/Plugins/Core/NotchPlugin.swift` — stable protocol
- `boringNotch/Plugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `boringNotch/Core/NotchStateMachine.swift` — pure and tested; only modify if state logic changes
- `boringNotch/private/CGSSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only

## Build & Verify
Always build after changes. Don't commit without a green build.
