# boring.notch Development Plan

> Consolidated roadmap for refactoring, features, and improvements.  
> Last updated: 2025-12-29

---

## Quick Stats

| Metric | Value | Target |
|--------|-------|--------|
| Total Swift Lines | ~23,000 | - |
| `.shared` Singletons | 312 | < 50 |
| Settings Usages (`Defaults`) | 264 | Centralized |
| `DispatchQueue.main` Calls | 62 | Use `@MainActor` |
| `NotificationCenter` Posts | 34 | Use Combine |
| Largest File | ShelfItemViewModel (1107) | < 300 |

---

## 🔥 Priority Queue

### P0: Critical Bugs

- [ ] **Button hover states** - Ensure all buttons respond correctly

### P1: Architecture Debt
- [ ] **Reduce singleton abuse** (312 → < 50)
- [ ] **Split ShelfItemViewModel** (1107 lines → 3-4 files)
- [ ] **Split NotchHomeView** (651 lines)
- [ ] **Extract MusicLiveActivity** from ContentView

### P2: Feature Polish
- [ ] **Calendar EventKit integration** - Already works, needs UI polish
- [ ] **Weather widget** - OpenWeatherMap integrated, needs display work
- [ ] **Liquid Glass effect** - ScreenCaptureKit blur working, fallback could improve

### P3: New Features
- [ ] Pomodoro timer widget
- [ ] Quick Notes widget
- [ ] System stats (CPU/RAM) widget
- [ ] App launcher shortcuts

### P4: Modernization & Cleanup (Technical Debt)
- [x] **Linting**: Add SwiftLint configuration (`.swiftlint.yml` added)
- [ ] **Concurrency**: Migrate `DispatchQueue.main.async` to `@MainActor` / `Task`
- [ ] **State Management**: Migrate `ObservableObject` to Swift 5.9 `@Observable` macro (macOS 15+ target allows this)
- [ ] **Formatting**: Add SwiftFormat for consistent style
- [ ] **Assets**: Move hardcoded colors/icons to Asset Catalog


---

## Architecture Overview

### Current State (Problem)

```
┌──────────────────────────────────────────────────────────────┐
│                        App Layer                              │
│  AppDelegate (402 lines) ──► Creates windows, drag detection │
└───────────────────────────────┬──────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────┐
│                       View Layer                              │
│  ContentView (588) ◄──► NotchHomeView (651)                  │
│       │                        │                              │
│       │ @ObservedObject        │ 24 .shared refs              │
│       ▼                        ▼                              │
│  MusicManager.shared     BoringViewCoordinator.shared        │
│  BatteryModel.shared     ShelfStateViewModel.shared          │
│  BrightnessManager.shared    ... (12+ singletons)            │
└──────────────────────────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────┐
│                      Manager Layer                            │
│  18 manager files, each a singleton                          │
│  MusicManager (642) ── knows about BoringViewCoordinator     │
│  VolumeManager (378)                                          │
│  WebcamManager (313)                                          │
└──────────────────────────────────────────────────────────────┘
```

### Target State

```
┌──────────────────────────────────────────────────────────────┐
│                    DependencyContainer                        │
│  Single entry point for all dependencies                      │
│  Protocol-based for testability                               │
└───────────────────────────────┬──────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────┐
│                     Coordinator Layer                         │
│  WindowCoordinator ✅   KeyboardShortcutCoordinator ✅        │
│  DragDetectionCoordinator ✅   NotchContentRouter ✅          │
└───────────────────────────────┬──────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────┐
│                    State Machine                              │
│  NotchStateMachine ✅ - Single source of truth for state     │
└───────────────────────────────┬──────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────┐
│                       View Layer                              │
│  Small, focused components (< 300 lines each)                │
│  No direct singleton access - uses passed dependencies        │
└──────────────────────────────────────────────────────────────┘
```

---

## God Objects to Split

| File | Lines | Split Into |
|------|-------|------------|
| `ShelfItemViewModel.swift` | 1107 | `ShelfFileHandler`, `ShelfImageProcessor`, `ShelfDropHandler`, `ShelfStorageService` |
| `NotchHomeView.swift` | 651 | `NotchTabBar`, `NotchContentArea`, `NotchQuickActions` |
| `MusicManager.swift` | 642 | `MusicPlaybackManager`, `MusicArtworkManager`, `MusicLyricsManager` |
| `ContentView.swift` | 588 | Already started with `NotchContentRouter` ✅ |
| `NowPlayingController.swift` | 426 | `NowPlayingObserver`, `NowPlayingParser` |

---

## Completed Work ✅

### Phase 1: Foundation (Done)
- [x] `Core/DependencyContainer.swift` - Centralized facade
- [x] `Core/NotchSettings.swift` - Protocol abstraction
- [x] `Core/NotchStateMachine.swift` - State logic extracted

### Phase 2: Coordinators (Done)
- [x] `Core/WindowCoordinator.swift` - Window management
- [x] `Core/KeyboardShortcutCoordinator.swift` - Shortcuts
- [x] `Core/DragDetectionCoordinator.swift` - Drag detection
- [x] `Core/NotchContentRouter.swift` - Content routing

### Phase 3: Decoupling (Done)
- [x] `BoringViewModel.swift` - Removed @ObservedObject singletons
- [x] `MusicManager.swift` - Publisher pattern for sneakPeekRequest

### Phase 4: Testing (Partial)
- [x] `NotchStateMachineTests.swift` - Unit tests skeleton
- [ ] Add test target in Xcode (File > New > Target)

### Recent Feature Work (2025-12-29)
- [x] **Metal Liquid Glass** - ScreenCaptureKit blur effect
- [x] **Calendar Widget** - Rebuilt with WeekDayPicker (Mon-Sat layout)
- [x] **Korean strings fixed** - NotificationsView now English
- [x] **Black notch overlay** - Fixed for Liquid Glass mode

---

## Remaining Refactoring

### ContentView Cleanup
```
Current ContentView responsibilities:
├── Layout calculation (computedChinWidth, etc.)
├── Gesture handling (handleDownGesture, handleUpGesture)
├── Hover state management
├── Drop target handling
├── Animation coordination
├── State routing (nested if-else)
└── 7+ singleton observations

Target:
├── NotchContainerView - Shell with gestures
├── NotchContentRouter - State → View mapping ✅
├── NotchGestureHandler - Extracted gesture logic
└── Layout computed in BoringViewModel
```

### ShelfItemViewModel Breakdown
```
Current (1107 lines):
├── File type detection
├── Image processing (thumbnails, resizing)
├── Drop handling
├── Persistence
├── Sharing
└── 56 .shared references (!)

Split into:
├── ShelfItem.swift - Model only
├── ShelfFileHandler.swift - File operations
├── ShelfImageProcessor.swift - Thumbnail generation
├── ShelfDropHandler.swift - Drop target logic
└── ShelfStorageService.swift - Persistence
```

---

## Feature Roadmap

### Near Term
| Feature | Status | Notes |
|---------|--------|-------|
| Calendar integration | ✅ Working | EventKit connected, new UI |
| Weather widget | ⚠️ Partial | OpenWeatherMap API, needs key |
| Liquid Glass effect | ✅ Working | Metal blur + fallback |
| Notifications panel | ✅ Working | Strings fixed |

### Medium Term
| Feature | Complexity | Description |
|---------|------------|-------------|
| Widget customization | Medium | Drag to reorder, show/hide |
| Pomodoro timer | Medium | Work/break timer in notch |
| Quick Notes | Low | Capture notes, sync to Notes.app |
| System stats | Medium | CPU, RAM, network in closed notch |

### Long Term
| Feature | Complexity | Description |
|---------|------------|-------------|
| Plugin system | High | Third-party widgets |
| iOS companion | High | Handoff, sync |
| Themes | Medium | Custom color schemes |

---

## Code Quality Checklist

### Files Needing Attention
- [ ] `ShelfItemViewModel.swift` - 56 singleton refs, 1107 lines
- [ ] `NotchHomeView.swift` - 24 singleton refs, 651 lines
- [ ] `MusicManager.swift` - Knows about view coordinator
- [ ] `ContentView.swift` - Nested if-else, 7+ singletons

### Patterns to Eliminate
- [ ] `@ObservedObject var x = SomeClass.shared` in ViewModels
- [ ] Direct `Defaults[.setting]` in Views (use ViewModel)
- [ ] `DispatchQueue.main.async` (use `@MainActor`)
- [ ] Magic numbers (extract to Constants)
- [ ] Nested if-else for state (use switch on enum)

### Patterns to Adopt
- [x] `DependencyContainer` for singleton access
- [x] `NotchStateMachine` for state determination
- [x] Publisher/Subscriber for cross-manager communication
- [ ] View-specific ViewModels (not shared)
- [ ] Coordinator pattern for navigation

---

## Testing Strategy

### Unit Tests
- [x] `NotchStateMachineTests` - State computation
- [ ] `ShelfItemTests` - File handling
- [ ] `MusicManagerTests` - Playback state

### Integration Tests
- [ ] Calendar permission flow
- [ ] Screen recording permission flow
- [ ] Multi-display window positioning

### Manual Test Checklist
- [ ] Notch opens/closes on hover
- [ ] Music controls work
- [ ] Calendar shows events
- [ ] Shelf accepts drops
- [ ] Works on external displays
- [ ] Works on displays without notch

---

## Quick Wins (Do These First)


2. **Add missing test target** - File > New > Target > Unit Testing
3. **Extract `computedChinWidth`** - Move to BoringViewModel
4. **Magic numbers → Constants** - `chinWidth = 640` → `Constants.batteryWidth`
5. **Replace DispatchQueue.main** - Use `@MainActor` or `Task { @MainActor in }`

---

## Files Reference

### Core (Architecture)
| File | Lines | Purpose |
|------|-------|---------|
| `DependencyContainer.swift` | 83 | Singleton facade |
| `NotchSettings.swift` | 131 | Settings protocol |
| `NotchStateMachine.swift` | 246 | State logic |
| `WindowCoordinator.swift` | 278 | Window management |
| `NotchContentRouter.swift` | 382 | Content routing |

### Managers
| File | Lines | Purpose |
|------|-------|---------|
| `MusicManager.swift` | 642 | Media playback |
| `VolumeManager.swift` | 378 | System volume |
| `BatteryActivityManager.swift` | 324 | Battery monitoring |
| `CalendarManager.swift` | 205 | EventKit integration |
| `WeatherManager.swift` | 252 | Weather API |
| `LiquidGlassManager.swift` | 196 | Screen capture blur |

### Components (Largest)
| File | Lines | Purpose |
|------|-------|---------|
| `ShelfItemViewModel.swift` | 1107 | Shelf item logic |
| `NotchHomeView.swift` | 651 | Main open view |
| `ContentView.swift` | 588 | Root view |
| `BoringCalendar.swift` | 379 | Calendar UI |
| `LiquidGlass.swift` | 354 | Glass effect |

---

*This plan consolidates REFACTORING_PLAN.md and provides an actionable roadmap.*
