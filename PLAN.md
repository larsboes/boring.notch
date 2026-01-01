# boring.notch Development Plan

> **Goal:** Refactor to a clean, plugin-first architecture where every feature is a plugin.
>
> Last updated: 2026-01-01

---

## Architecture Vision

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SwiftUI Views                                   │
│   - No .shared access                                                       │
│   - Dependencies via @Environment(PluginManager.self)                       │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                            PluginManager                                     │
│   - Owns all plugin instances                                               │
│   - Handles lifecycle (activate/deactivate)                                 │
│   - Routes view requests to plugins                                         │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                         NotchPlugin Instances                                │
│   MusicPlugin, CalendarPlugin, ShelfPlugin, WeatherPlugin, BatteryPlugin   │
│   - Each implements NotchPlugin protocol                                    │
│   - Capability mix-ins: PlayablePlugin, ExportablePlugin, etc.             │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                          Service Protocols                                   │
│   MusicServiceProtocol, CalendarServiceProtocol, ShelfServiceProtocol      │
│   - Wrap system APIs (MediaPlayer, EventKit, CoreAudio)                    │
│   - Injected into plugins via PluginContext                                │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                            Infrastructure                                    │
│   - PluginSettings (namespaced Defaults wrapper)                            │
│   - PluginEventBus (inter-plugin communication)                             │
│   - System APIs                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Core Principle:** Every feature is a plugin. Built-in features use the same APIs as future third-party plugins.

---

## Current State

| Metric | Current | Target |
|--------|---------|--------|
| `.shared` Singletons | 320 | 0 in views |
| `Defaults[.]` direct access | 246 | Via PluginSettings only |
| Manager protocols | 2 | All managers |
| Plugins migrated | 0 | 6 built-in |

### What Exists

- [x] `Plugins/Core/NotchPlugin.swift` - Core plugin protocol
- [x] `Plugins/Core/PluginCapabilities.swift` - PlayablePlugin, ExportablePlugin, etc.
- [x] `Plugins/Core/PluginManager.swift` - Registry and lifecycle
- [x] `Plugins/Core/PluginContext.swift` - DI context + service protocols
- [x] `Plugins/Core/PluginSettings.swift` - Namespaced settings wrapper
- [x] `Plugins/Core/PluginEventBus.swift` - Inter-plugin communication
- [x] `Plugins/BuiltIn/MusicPlugin/MusicPlugin.swift` - Skeleton example

### What's Missing

- [ ] Service implementations (MusicService, CalendarService, etc.)
- [ ] Wiring PluginManager into app lifecycle
- [ ] Migrating existing managers to services
- [ ] Updating views to use PluginManager

---

## Migration Phases

### Phase 1: Wire Up Plugin Infrastructure

**Goal:** Get PluginManager running with empty plugins, no functionality change yet.

| Task | Description |
|------|-------------|
| Create `ServiceContainer` | Instantiate all service protocols with existing managers as backing |
| Wire `PluginManager` in App | Create in `boringNotchApp.swift`, inject via `.environment()` |
| Create `AppState` adapter | Implement `AppStateProviding` using existing `BoringViewModel` |
| Register empty plugins | All 6 plugins registered but returning nil views |

**Success:** App launches, PluginManager exists, no visual changes.

### Phase 2: Migrate Music (First Plugin)

**Goal:** Music functionality fully migrated to plugin architecture.

| Task | Description |
|------|-------------|
| Create `MusicService` | Extract from `MusicManager`, implement `MusicServiceProtocol` |
| Complete `MusicPlugin` | Wire service, implement all 3 view slots |
| Update `NotchContentRouter` | Query PluginManager for music views |
| Remove direct access | No more `MusicManager.shared` in views |
| Settings migration | Move music settings to `PluginSettings` |

**Success:** Music controls work entirely through plugin system.

### Phase 3: Migrate Remaining Plugins

| Order | Plugin | Service | Complexity |
|-------|--------|---------|------------|
| 1 | ✅ MusicPlugin | MusicService | Medium |
| 2 | BatteryPlugin | BatteryService | Low |
| 3 | CalendarPlugin | CalendarService | Medium |
| 4 | WeatherPlugin | WeatherService | Low |
| 5 | ShelfPlugin | ShelfService | High |
| 6 | WebcamPlugin | WebcamService | Low |
| 7 | NotificationsPlugin | NotificationsService | Medium |

### Phase 4: Cleanup Legacy Code

| Task | Description |
|------|-------------|
| Delete `DependencyContainer` | Replaced by `ServiceContainer` |
| Delete singleton `.shared` | All access via DI |
| Delete direct `Defaults[.]` | All via `PluginSettings` |
| Delete `NotificationCenter` posts | All via `PluginEventBus` |
| Archive old managers | Keep for reference, remove from build |

### Phase 5: Enhanced Architecture

| Task | Description |
|------|-------------|
| Data export | Implement `ExportablePlugin` for all plugins |
| Local API server | REST endpoints for external integration |
| App Intents | Shortcuts integration via plugins |
| Third-party plugin loading | Runtime discovery and loading |

---

## Protocol Reference

### NotchPlugin (Core)

```swift
@MainActor
protocol NotchPlugin: Identifiable, Observable {
    var id: String { get }
    var metadata: PluginMetadata { get }
    var isEnabled: Bool { get set }
    var state: PluginState { get }

    func activate(context: PluginContext) async throws
    func deactivate() async

    func closedNotchContent() -> AnyView?
    func expandedPanelContent() -> AnyView?
    func settingsContent() -> AnyView?
}
```

### Capability Protocols

| Protocol | Purpose |
|----------|---------|
| `PlayablePlugin` | Media playback controls |
| `ExportablePlugin` | Data export in multiple formats |
| `DropReceivingPlugin` | Accept dropped files/content |
| `PositionedPlugin` | Specify closed notch position |
| `NotifyingPlugin` | Send notifications |
| `SearchablePlugin` | Searchable content |

### Service Protocols

| Protocol | Wraps |
|----------|-------|
| `MusicServiceProtocol` | MediaPlayer, Spotify, YouTube Music |
| `CalendarServiceProtocol` | EventKit |
| `ShelfServiceProtocol` | File management |
| `WeatherServiceProtocol` | Weather API |
| `VolumeServiceProtocol` | CoreAudio |
| `BrightnessServiceProtocol` | Display services |
| `BatteryServiceProtocol` | IOKit battery info |
| `BluetoothServiceProtocol` | CoreBluetooth |

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Plugin loading | Compile-time for now | Runtime loading is complex; architecture supports both |
| View type erasure | `AnyView` at protocol boundary | Need heterogeneous plugin collections |
| Inter-plugin comm | Hybrid (DI + event bus) | Type-safe for tight coupling, events for loose |
| Settings storage | Namespaced Defaults | Simpler than new persistence; `PluginSettings` wraps it |
| Service ownership | ServiceContainer owns | Single source of truth, injected at app launch |

---

## Anti-Patterns to Eliminate

### 1. Singleton Access in Views

```swift
// ❌ BAD - Direct singleton
struct MusicView: View {
    let manager = MusicManager.shared
}

// ✅ GOOD - Via PluginManager
struct MusicView: View {
    @Environment(PluginManager.self) var plugins

    var musicPlugin: MusicPlugin? {
        plugins.plugin(id: "com.boringnotch.music") as? MusicPlugin
    }
}
```

### 2. Scattered Settings

```swift
// ❌ BAD - Direct Defaults access
if Defaults[.enableSneakPeek] { ... }

// ✅ GOOD - Via PluginSettings
let sneakPeek = settings.get("enableSneakPeek", default: true)
```

### 3. NotificationCenter for Internal Events

```swift
// ❌ BAD - NotificationCenter
NotificationCenter.default.post(name: .trackChanged, object: track)

// ✅ GOOD - PluginEventBus
eventBus.emit(MusicTrackChangedEvent(track: track))
```

### 4. DispatchQueue.main

```swift
// ❌ BAD - Manual dispatch
DispatchQueue.main.async { self.isPlaying = true }

// ✅ GOOD - MainActor
@MainActor func updatePlayState() { self.isPlaying = true }
```

---

## Files Structure

```
boringNotch/
├── Plugins/
│   ├── Core/
│   │   ├── NotchPlugin.swift
│   │   ├── PluginCapabilities.swift
│   │   ├── PluginManager.swift
│   │   ├── PluginContext.swift
│   │   ├── PluginSettings.swift
│   │   └── PluginEventBus.swift
│   │
│   ├── Services/                    # TODO: Create
│   │   ├── ServiceContainer.swift
│   │   ├── MusicService.swift
│   │   ├── CalendarService.swift
│   │   ├── ShelfService.swift
│   │   └── ...
│   │
│   └── BuiltIn/
│       ├── MusicPlugin/
│       │   └── MusicPlugin.swift
│       ├── CalendarPlugin/          # TODO: Create
│       ├── ShelfPlugin/             # TODO: Create
│       ├── WeatherPlugin/           # TODO: Create
│       ├── BatteryPlugin/           # TODO: Create
│       └── WebcamPlugin/            # TODO: Create
│
├── Core/                            # Existing, keep
│   ├── NotchStateMachine.swift
│   ├── WindowCoordinator.swift
│   └── NotchContentRouter.swift     # Update to use PluginManager
│
└── Legacy/                          # Move old code here during migration
    ├── DependencyContainer.swift
    └── ...
```

---

## Completed Work (Pre-Plugin Era)

### Foundation
- [x] NotchStateMachine - State logic extracted
- [x] WindowCoordinator - Window management
- [x] NotchContentRouter - Content routing
- [x] @Observable migration - All major classes

### God Object Splitting
- [x] ShelfItemViewModel - 1107 → 75 lines
- [x] NotchHomeView - 651 → 109 lines

### Effects
- [x] Metal Liquid Glass + SwiftGlass
- [x] Calendar Widget with WeekDayPicker

---

## Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Architecture | `.ai-docs/ARCHITECTURE.md` | Full plugin system design |
| Feature Ideas | `.ai-docs/FEATURE_IDEAS.md` | Future plugins and integrations |
| Codebase Analysis | `.ai-docs/analysis/` | Initial code review |

---

## Next Actions

1. **Create `ServiceContainer`** - Wrap existing managers with service protocols
2. **Wire `PluginManager` in app** - Create at launch, inject to environment
3. **Implement `AppStateProviding`** - Adapter for existing BoringViewModel
4. **Complete `MusicService`** - First real service extraction
5. **Update one view** - Prove the pattern works end-to-end

---

## Low Priority (After Architecture)

These are nice-to-haves that should wait until the plugin migration is complete:

- [ ] Button hover states audit
- [ ] Magic numbers → Constants
- [ ] Asset catalog migration
- [ ] Swift 6 strict concurrency

---

*This plan focuses on clean architecture. Quick fixes are deferred until the foundation is solid.*
