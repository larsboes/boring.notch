# Boring.Notch Refactoring Plan

## Executive Summary

This document outlines the architectural issues identified in the boring.notch codebase and provides a phased refactoring strategy to address them. The codebase has grown organically and shows classic signs of feature creep without proper refactoring.

**Key Problems:**
- Singleton abuse (260+ `.shared` occurrences)
- God objects (AppDelegate: 610 lines, ContentView: 700 lines, MusicManager: 621 lines)
- No dependency injection
- Untestable architecture
- State management chaos

---

## Part 1: Architectural Analysis

### 1.1 The Singleton Web

Current dependency graph:

```
                    ┌─────────────────────────────────────────┐
                    │              AppDelegate                │
                    │  (owns windows, VMs, drag detectors)    │
                    └─────────────┬───────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────────┐
          ▼                       ▼                           ▼
    BoringViewModel        BoringViewCoordinator.shared   QuickShareService.shared
          │                       │
          │ @ObservedObject       │ @Published state
          ▼                       │
    ┌─────────────────────────────┼─────────────────────────────┐
    │                             ▼                             │
    │                      ContentView                          │
    │    @EnvironmentObject vm    (700 lines)                   │
    │    @ObservedObject coordinator = .shared                  │
    │    @ObservedObject musicManager = .shared                 │
    │    @ObservedObject batteryModel = .shared                 │
    │    @ObservedObject brightnessManager = .shared            │
    │    @ObservedObject volumeManager = .shared                │
    │    @ObservedObject webcamManager = .shared                │
    └───────────────────────────────────────────────────────────┘
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    │                             │                             │
    ▼                             ▼                             ▼
MusicManager.shared    BatteryStatusViewModel.shared   ShelfStateViewModel.shared
    │                             │
    │ @ObservedObject             │ @ObservedObject
    ▼                             ▼
BoringViewCoordinator.shared  BoringViewCoordinator.shared
```

**Problems:**
- Every component references every other component through singletons
- Circular awareness between components
- Unpredictable re-renders
- Untraceable data flow

### 1.2 Specific Anti-Patterns

#### 1.2.1 ViewModel with @ObservedObject to Singletons

**Location:** `boringNotch/models/BoringViewModel.swift:13-14`

```swift
class BoringViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = BoringViewCoordinator.shared  // Wrong!
    @ObservedObject var detector = FullscreenMediaDetector.shared   // Wrong!
}
```

**Problem:** A ViewModel shouldn't observe singletons via `@ObservedObject`. It couples the VM to global state and causes the VM to re-publish on singleton changes.

#### 1.2.2 Data Manager Knowing About View Coordinator

**Location:** `boringNotch/managers/MusicManager.swift:50`

```swift
@ObservedObject var coordinator = BoringViewCoordinator.shared
```

**Problem:** A data manager shouldn't know about a view coordinator. This violates separation of concerns.

#### 1.2.3 Business Logic in View

**Location:** `boringNotch/ContentView.swift:85-105`

```swift
private var computedChinWidth: CGFloat {
    var chinWidth: CGFloat = vm.closedNotchSize.width

    if coordinator.expandingView.type == .battery && coordinator.expandingView.show
        && vm.notchState == .closed && Defaults[.showPowerStatusNotifications] { ... }
    else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
        && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
        && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed { ... }
    // ...
}
```

**Problem:** Complex branching logic should be in a ViewModel, not a computed property in the View.

#### 1.2.4 State Determination via Nested If-Else

**Location:** `boringNotch/ContentView.swift:271-392`

The `NotchLayout()` function is a 120-line `@ViewBuilder` with nested if-else chains determining what to render. This should be a state machine pattern.

#### 1.2.5 Massive applicationDidFinishLaunching

**Location:** `boringNotch/boringNotchApp.swift:287-446`

160 lines of setup code including:
- 5+ NotificationCenter observers
- 2 DistributedNotificationCenter observers
- 2 keyboard shortcuts
- Window creation logic
- Onboarding logic

Each responsibility should be in its own coordinator.

### 1.3 God Objects

| File | Lines | Responsibilities |
|------|-------|------------------|
| `AppDelegate` | 610 | Window management, drag detection, screen lock handling, keyboard shortcuts, onboarding, settings coordination |
| `ContentView` | 700 | Layout, gestures, hover, drop handling, state routing, animations |
| `MusicManager` | 621 | Controller management, playback state, artwork, color extraction, lyrics, volume, UI state |
| `BoringViewCoordinator` | 300 | View state, sneak peek, expanding view, settings storage, screen preferences, HUD replacement |

### 1.4 Settings Sprawl

Found **182 occurrences** of `@Default` and `Defaults[` across 35 files.

**Problems:**
- No type safety
- No validation
- Scattered across codebase
- Business logic mixed with configuration

---

## Part 2: Refactoring Strategy

### Phase 1: Create the Foundation (Low Risk)

**Goal:** Introduce proper architecture without changing existing code.

#### 1.1 Create a Dependency Container

**New file:** `boringNotch/Core/DependencyContainer.swift`

```swift
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // Lazy singletons - same instances, just centralized
    lazy var musicManager = MusicManager()
    lazy var viewCoordinator = ViewCoordinator()
    lazy var batteryViewModel = BatteryStatusViewModel()
    lazy var brightnessManager = BrightnessManager()
    lazy var volumeManager = VolumeManager()
    lazy var shelfViewModel = ShelfStateViewModel()

    private init() {}
}

// Protocol for testability
protocol DependencyProviding {
    var musicManager: MusicManager { get }
    var viewCoordinator: ViewCoordinator { get }
    // ...
}
```

#### 1.2 Create a NotchState Machine

**New file:** `boringNotch/Core/NotchStateMachine.swift`

```swift
enum NotchDisplayState: Equatable {
    case closed(content: ClosedContent)
    case open(view: NotchViews)
    case sneakPeek(type: SneakContentType, value: CGFloat)
    case expanding(type: SneakContentType)

    enum ClosedContent: Equatable {
        case idle
        case musicLiveActivity
        case batteryNotification
        case hud(type: SneakContentType, value: CGFloat)
        case face
    }
}

@MainActor
class NotchStateMachine: ObservableObject {
    @Published private(set) var state: NotchDisplayState = .closed(content: .idle)

    // Centralized state determination - all branching logic from ContentView moves here
    func computeState(
        notchState: NotchState,
        isPlaying: Bool,
        isPlayerIdle: Bool,
        expandingView: ExpandedItem,
        sneakPeek: sneakPeek,
        settings: NotchSettings
    ) -> NotchDisplayState {
        // Testable state computation
    }

    func transition(to newState: NotchDisplayState) {
        state = newState
    }
}
```

#### 1.3 Create a Settings Protocol

**New file:** `boringNotch/Core/NotchSettings.swift`

```swift
protocol NotchSettings {
    var showInlineHUD: Bool { get }
    var hudReplacement: Bool { get }
    var showPowerStatusNotifications: Bool { get }
    var showNotHumanFace: Bool { get }
    var musicLiveActivityEnabled: Bool { get }
}

// Production implementation
struct DefaultsNotchSettings: NotchSettings {
    var showInlineHUD: Bool { Defaults[.inlineHUD] }
    var hudReplacement: Bool { Defaults[.hudReplacement] }
    // ...
}

// Test implementation
struct MockNotchSettings: NotchSettings {
    var showInlineHUD: Bool = false
    var hudReplacement: Bool = false
    // ...
}
```

---

### Phase 2: Decouple ViewModels (Medium Risk)

**Goal:** Remove singleton references from ViewModels.

#### 2.1 Fix BoringViewModel

**Before:**
```swift
class BoringViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared
}
```

**After:**
```swift
class BoringViewModel: NSObject, ObservableObject {
    private let stateMachine: NotchStateMachine
    private let fullscreenDetector: FullscreenMediaDetector

    init(
        stateMachine: NotchStateMachine = .shared,
        fullscreenDetector: FullscreenMediaDetector = .shared
    ) {
        self.stateMachine = stateMachine
        self.fullscreenDetector = fullscreenDetector
        super.init()
        setupBindings()
    }

    private func setupBindings() {
        // Subscribe to detector changes via Combine, not @ObservedObject
    }
}
```

#### 2.2 Fix MusicManager - Remove Coordinator Coupling

**Before:** (`MusicManager.swift:466-474`)
```swift
private func updateSneakPeek() {
    if isPlaying && Defaults[.enableSneakPeek] {
        if Defaults[.sneakPeekStyles] == .standard {
            coordinator.toggleSneakPeek(status: true, type: .music)
        } else {
            coordinator.toggleExpandingView(status: true, type: .music)
        }
    }
}
```

**After - Use delegation or Publisher:**
```swift
protocol MusicManagerDelegate: AnyObject {
    func musicManager(_ manager: MusicManager, didStartPlaying track: String)
    func musicManager(_ manager: MusicManager, requestsSneakPeek type: SneakPeekRequest)
}

// Or use a Publisher
@Published var sneakPeekRequest: SneakPeekRequest?
```

---

### Phase 3: Split God Objects (Higher Risk)

**Goal:** Break up AppDelegate and ContentView.

#### 3.1 Extract from AppDelegate

Create new files:

```
boringNotch/Core/
├── WindowCoordinator.swift          // Window creation, positioning, multi-display
├── DragDetectionCoordinator.swift   // Drag detection setup and handling
├── ScreenLockObserver.swift         // Lock/unlock handling
├── KeyboardShortcutCoordinator.swift // Keyboard shortcuts
└── OnboardingCoordinator.swift      // Onboarding flow
```

**WindowCoordinator.swift:**
```swift
@MainActor
class WindowCoordinator {
    private var windows: [String: NSWindow] = [:]
    private var viewModels: [String: BoringViewModel] = [:]
    private let settings: NotchSettings

    init(settings: NotchSettings = DefaultsNotchSettings()) {
        self.settings = settings
    }

    func adjustWindowPosition(changeAlpha: Bool = false) {
        // Move ~70 lines from AppDelegate here
    }

    func createWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        // Move window creation logic here
    }
}
```

#### 3.2 Split ContentView

Create subviews:

```
boringNotch/components/Notch/
├── NotchContainerView.swift     // The outer shell (gestures, hover, shape)
├── NotchContentRouter.swift     // The if-else state routing (uses StateMachine)
├── NotchClosedContent.swift     // Battery, Music, HUD, Face views
├── NotchOpenContent.swift       // Home, Shelf routing
└── NotchGestureHandler.swift    // Extract gesture logic
```

**NotchContentRouter.swift:**
```swift
struct NotchContentRouter: View {
    let state: NotchDisplayState
    let albumArtNamespace: Namespace.ID

    var body: some View {
        switch state {
        case .closed(let content):
            NotchClosedContent(content: content)
        case .open(let view):
            NotchOpenContent(view: view, namespace: albumArtNamespace)
        case .sneakPeek(let type, let value):
            SneakPeekView(type: type, value: value)
        case .expanding(let type):
            ExpandingView(type: type)
        }
    }
}
```

---

### Phase 4: Add Testing Infrastructure

**Goal:** Make the codebase testable.

**New file:** `boringNotchTests/NotchStateMachineTests.swift`

```swift
final class NotchStateMachineTests: XCTestCase {
    func testClosedWithMusic_ShowsLiveActivity() {
        let settings = MockNotchSettings(musicLiveActivityEnabled: true)
        let machine = NotchStateMachine()

        let state = machine.computeState(
            notchState: .closed,
            isPlaying: true,
            isPlayerIdle: false,
            expandingView: .init(),
            sneakPeek: .init(),
            settings: settings
        )

        XCTAssertEqual(state, .closed(content: .musicLiveActivity))
    }

    func testClosedWithBattery_ShowsBatteryNotification() {
        let settings = MockNotchSettings(showPowerStatusNotifications: true)
        let machine = NotchStateMachine()

        let state = machine.computeState(
            notchState: .closed,
            isPlaying: false,
            isPlayerIdle: true,
            expandingView: ExpandedItem(show: true, type: .battery),
            sneakPeek: .init(),
            settings: settings
        )

        XCTAssertEqual(state, .closed(content: .batteryNotification))
    }
}
```

---

## Part 3: Implementation Order

### Recommended Sequence

| Step | Task | Files Affected | Risk | Impact |
|------|------|----------------|------|--------|
| 1 | Create `DependencyContainer` | New file only | Very Low | Foundation |
| 2 | Create `NotchSettings` protocol | New file only | Very Low | Testability |
| 3 | Create `NotchStateMachine` | New file + ContentView | Low | Clarity |
| 4 | Extract `WindowCoordinator` | New file + AppDelegate | Medium | Separation |
| 5 | Fix `BoringViewModel` singleton refs | BoringViewModel.swift | Medium | Decoupling |
| 6 | Fix `MusicManager` coordinator ref | MusicManager.swift | Medium | Decoupling |
| 7 | Split `ContentView` | Multiple new files | Higher | Maintainability |
| 8 | Add tests | New test files | Low | Confidence |

### Quick Wins (Do First)

1. **Create `NotchDisplayState` enum** - Immediately clarifies what states exist
2. **Move `computedChinWidth` to BoringViewModel** - 20 lines, instant improvement
3. **Extract gesture handlers** - `handleDownGesture` and `handleUpGesture` to separate file
4. **Replace magic numbers with constants** - `chinWidth = 640` → `Constants.batteryNotificationWidth`

---

## Part 4: File Structure After Refactoring

```
boringNotch/
├── Core/
│   ├── DependencyContainer.swift
│   ├── NotchStateMachine.swift
│   ├── NotchSettings.swift
│   ├── WindowCoordinator.swift
│   ├── DragDetectionCoordinator.swift
│   ├── ScreenLockObserver.swift
│   ├── KeyboardShortcutCoordinator.swift
│   └── OnboardingCoordinator.swift
├── components/
│   └── Notch/
│       ├── NotchContainerView.swift
│       ├── NotchContentRouter.swift
│       ├── NotchClosedContent.swift
│       ├── NotchOpenContent.swift
│       ├── NotchGestureHandler.swift
│       └── ... (existing files)
├── models/
│   └── BoringViewModel.swift (refactored)
├── managers/
│   └── MusicManager.swift (refactored)
└── boringNotchApp.swift (simplified AppDelegate)
```

---

## Part 5: Success Metrics

After refactoring, the codebase should:

1. **Have testable components** - State machine can be unit tested
2. **Have clear data flow** - Unidirectional, traceable
3. **Have single-responsibility classes** - No file > 300 lines
4. **Have dependency injection** - Singletons accessed through container
5. **Have fewer re-renders** - Views only observe what they need

---

## Appendix: Code Smells Reference

### Files to Watch

| File | Issue | Priority |
|------|-------|----------|
| `ContentView.swift` | 700 lines, nested if-else | High |
| `boringNotchApp.swift` | 610 line AppDelegate | High |
| `MusicManager.swift` | 621 lines, 15+ responsibilities | High |
| `BoringViewCoordinator.swift` | Misleading name, state dumping ground | Medium |
| `BoringViewModel.swift` | @ObservedObject to singletons | Medium |
| `NotchHomeView.swift` | 609 lines, embedded components | Medium |

### Patterns to Eliminate

- `@ObservedObject var x = SomeClass.shared` in ViewModels
- Direct `Defaults[.setting]` access in Views
- `NotificationCenter.default.post` for internal state changes
- Magic numbers without constants
- Nested if-else chains for state determination

---

*Document created: 2025-12-29*
*Last updated: 2025-12-29*
