# boring.notch Development Plan

> **Goal:** Refactor to a clean, plugin-first architecture where every feature is a plugin.
>
> Last updated: 2026-01-03 (Post-Modernization)

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
| `.shared` Singletons | 0 (in Views) | 0 |
| `Defaults[.]` direct access | Mixed | Via PluginSettings only |
| Manager protocols | 100% | All managers |
| Plugins migrated | 8/8 | 8 built-in |

### What Exists

- [x] **Plugin Core:** `PluginManager`, `NotchPlugin`, `ServiceContainer`.
- [x] **Services:** wrappers/implementations for Music, Battery, Calendar, Weather, Shelf, Webcam, Notifications.
- [x] **Plugins:** All built-ins (`MusicPlugin`, `BatteryPlugin`, `CalendarPlugin`, `WeatherPlugin`, `ShelfPlugin`, `WebcamPlugin`, `NotificationsPlugin`, `ClipboardPlugin`) created and active.
- [x] **Views:** `NotchHomeView` and `NotchContentRouter` fully migrated to use `PluginManager`.

### What's Missing

- [ ] **Unit Tests:** Now that protocols exist, we need to write tests for Plugins and Services.
- [ ] **Settings Migration:** Decouple internal Managers from global `Defaults`.
- [ ] **Data Export:** Implement `ExportablePlugin` for all plugins.

---

## Migration Phases

### Phase 1: Wire Up Plugin Infrastructure (✅ Complete)
- [x] Create `ServiceContainer`
- [x] Wire `PluginManager` in App
- [x] Create `AppState` adapter

### Phase 2: Migrate Music (First Plugin) (✅ Complete)
- [x] Create `MusicService`
- [x] Complete `MusicPlugin`
- [x] Update `NotchContentRouter`
- [x] Remove direct access

### Phase 3: Migrate Remaining Plugins (✅ Complete)
- [x] **BatteryPlugin**: Created `BatteryPlugin`, wrapped `BatteryService`.
- [x] **CalendarPlugin**: Created `CalendarPlugin`, wrapped `CalendarService`.
- [x] **WeatherPlugin**: Created `WeatherPlugin`, wrapped `WeatherService`.
- [x] **ShelfPlugin**: Created `ShelfPlugin`, wrapped `ShelfService`.
- [x] **WebcamPlugin**: Created `WebcamPlugin`, refactored `WebcamManager` to protocol.
- [x] **NotificationsPlugin**: Created `NotificationsPlugin`, migrated `NotificationCenterManager` to `@Observable`.

### Phase 4: Cleanup Legacy Code (✅ Complete)
- [x] Delete `DependencyContainer`
- [x] Delete singleton `.shared` access in Views
- [x] Delete legacy views (`MusicPlayerView`)

### Phase 5: Modernization & Decoupling (✅ Complete)
- [x] **Clipboard Plugin**: Created `ClipboardPlugin`, migrated `ClipboardView`.
- [x] **Service Decoupling**: Refactored `CalendarService` and `WeatherService` to use settings injection (`*SettingsProtocol`).
- [x] **Observable Migration**: Migrated `NotchStateMachine`, `DownloadWatcher`, `QuickLookService`, `QuickShareService`, and `NotchFaceManager` to `@Observable`.
- [x] **Cleanup**: Removed unused `Defaults` imports and ensured all managers are wrapped in services.

### Phase 6: Future Hardening & Features (Current)

**Goal:** Leverage the new architecture to improve quality and add "Pro" features.

| Task | Description | Priority |
|------|-------------|----------|
| **Unit Tests** | Create tests for `MusicPlugin` and `NotchStateMachine` using mock services. | High |
| **Settings Migration** | Continue refactoring remaining Managers to accept configuration (if any left). | Low |
| **Data Export** | Implement `ExportablePlugin` for `ShelfPlugin` (file list) and `CalendarPlugin`. | Medium |
| **Shelf Cleanup** | Move `ShelfSelectionModel` into `ShelfService` or Plugin state. | Low |

---

## Files Structure

```
boringNotch/
├── Plugins/
│   ├── Core/
│   │   ├── NotchPlugin.swift
│   │   ├── PluginManager.swift
│   │   └── ...
│   │
│   ├── Services/
│   │   ├── ServiceContainer.swift
│   │   ├── MusicService.swift
│   │   ├── BatteryService.swift
│   │   └── ...
│   │
│   └── BuiltIn/
│       ├── MusicPlugin/
│       ├── BatteryPlugin/
│       ├── CalendarPlugin/
│       ├── WeatherPlugin/
│       ├── ShelfPlugin/
│       ├── WebcamPlugin/
│       └── NotificationsPlugin/
```

---

*The architecture migration is complete. The codebase is now ready for stability improvements and new feature development.*