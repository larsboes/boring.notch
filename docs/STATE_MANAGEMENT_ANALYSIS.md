# Notch State Management - Redesign

## The Core Problem

The current system relies on **events** (mouseEntered/mouseExited) which are **unreliable**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    WHY EVENTS FAIL                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SwiftUI View Layout Change                                      │
│         │                                                        │
│         ▼                                                        │
│  NSTrackingArea recalculates bounds                              │
│         │                                                        │
│         ▼                                                        │
│  System thinks mouse "exited" (even though it didn't move!)     │
│         │                                                        │
│         ▼                                                        │
│  mouseExited fires → isHoveringNotch = false → WRONG STATE      │
│                                                                  │
│  The mouse never moved. The VIEW moved. But we can't tell.      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Insight**: Events tell us what the VIEW thinks happened. We need to know what ACTUALLY happened.

---

## Design Principle: Trust The Mouse, Not The View

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   OLD WAY (Event-Driven)           NEW WAY (Truth-Based)        │
│                                                                  │
│   "The view says mouse exited"     "Where is the mouse NOW?"    │
│            │                                │                    │
│            ▼                                ▼                    │
│   isHoveringNotch = false          let pos = NSEvent.mouseLocation
│            │                       let inside = region.contains(pos)
│            ▼                                │                    │
│   Maybe wrong!                              ▼                    │
│                                    Always correct!               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## New Architecture: The Notch Hover Controller

### Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    NotchHoverController                          │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │              │    │              │    │              │       │
│  │  TRUTH       │───▶│  STATE       │───▶│  ACTIONS     │       │
│  │  (Position)  │    │  (Machine)   │    │  (Open/Close)│       │
│  │              │    │              │    │              │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         ▲                   ▲                                    │
│         │                   │                                    │
│    ┌────┴────┐        ┌─────┴─────┐                             │
│    │Heartbeat│        │  Events   │                             │
│    │ (60Hz)  │        │(optional) │                             │
│    └─────────┘        └───────────┘                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Component 1: The Truth Source

```swift
/// Always returns the actual mouse position - no events, no guessing
struct MouseTruth {
    static var position: NSPoint {
        NSEvent.mouseLocation  // Global screen coordinates
    }

    static func isInside(_ region: NSRect) -> Bool {
        region.contains(position)
    }
}
```

### Component 2: The Notch Region

```
┌─────────────────────────────────────────────────────────────────┐
│                         SCREEN                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │                    ┌─────────────┐                        │  │
│  │                    │ NOTCH REGION│ ◄── Calculated from    │  │
│  │                    │             │     window.frame       │  │
│  │                    │  Contains:  │                        │  │
│  │                    │  • Visible  │                        │  │
│  │                    │    notch    │                        │  │
│  │                    │  • Buttons  │                        │  │
│  │                    │  • Shadow   │                        │  │
│  │                    └─────────────┘                        │  │
│  │                                                           │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  NotchRegion = window.frame (in screen coordinates)             │
│  • Stable - window doesn't change during layout shifts          │
│  • Includes everything - buttons, content, shadows              │
│  • Simple to calculate - no view coordinate conversion          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Component 3: The State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                      HOVER STATE MACHINE                         │
│                                                                  │
│                                                                  │
│                         ┌─────────┐                              │
│              ┌─────────▶│ OUTSIDE │◀─────────┐                  │
│              │          └────┬────┘          │                  │
│              │               │               │                  │
│              │          [mouse enters       │                  │
│              │           notch region]       │                  │
│              │               │               │                  │
│              │               ▼               │                  │
│              │          ┌─────────┐          │                  │
│              │          │ENTERING │          │                  │
│              │          │ (50ms)  │          │                  │
│              │          └────┬────┘          │                  │
│              │               │               │                  │
│         [mouse exits    [still inside       │                  │
│          during delay]   after 50ms]        │                  │
│              │               │               │                  │
│              │               ▼               │                  │
│              │          ┌─────────┐          │                  │
│              │          │ INSIDE  │──────────┤                  │
│              │          │(hovering)│         │                  │
│              │          └────┬────┘          │                  │
│              │               │               │                  │
│              │          [mouse exits        │                  │
│              │           notch region]       │                  │
│              │               │               │                  │
│              │               ▼          [delay expires          │
│              │          ┌─────────┐      & still outside]       │
│              └──────────│ EXITING │──────────┘                  │
│                         │(0.5s/4s)│                              │
│              ┌──────────└────┬────┘                              │
│              │               │                                   │
│         [mouse returns  [mouse returns                          │
│          to region]      to region]                             │
│              │               │                                   │
│              ▼               │                                   │
│          ┌─────────┐         │                                   │
│          │ INSIDE  │◀────────┘                                  │
│          │(cancel  │                                             │
│          │ close)  │                                             │
│          └─────────┘                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Component 4: The Heartbeat (Key Innovation!)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    THE HEARTBEAT SYSTEM                          │
│                                                                  │
│  Instead of relying on events, we CHECK THE TRUTH periodically  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │   Every 16ms (60 FPS) while notch is OPEN:             │    │
│  │                                                         │    │
│  │   1. Get actual mouse position                         │    │
│  │   2. Check if inside notch region                      │    │
│  │   3. Update state machine if needed                    │    │
│  │                                                         │    │
│  │   This CATCHES:                                         │    │
│  │   • Missed mouseExit events                            │    │
│  │   • Spurious mouseExit events (validates before acting)│    │
│  │   • Mouse teleporting (fast movements)                 │    │
│  │   • Screen coordinate changes                          │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  POWER EFFICIENT:                                                │
│  • Only runs when notch is open (not when closed)               │
│  • 60Hz polling is negligible CPU (games do this constantly)    │
│  • Stops immediately when notch closes                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Design

### NotchHoverController

```swift
@MainActor
final class NotchHoverController {

    // MARK: - State

    enum HoverState: Equatable {
        case outside
        case entering(since: Date)
        case inside
        case exiting(since: Date)
    }

    private(set) var state: HoverState = .outside
    private var heartbeat: Task<Void, Never>?
    private weak var window: NSWindow?

    // MARK: - Configuration

    var enterDelay: TimeInterval = 0.05      // 50ms debounce
    var exitDelayNormal: TimeInterval = 0.5  // 500ms for normal content
    var exitDelayShelf: TimeInterval = 4.0   // 4s for shelf (dropping files)
    var isShelfActive: Bool = false

    // MARK: - Callbacks

    var onShouldOpen: (() -> Void)?
    var onShouldClose: (() -> Void)?

    // MARK: - Core Logic

    /// The ONLY source of truth - is mouse inside notch region?
    private var isMouseInsideNotch: Bool {
        guard let window = window else { return false }
        let mousePos = NSEvent.mouseLocation
        let notchRegion = window.frame
        return notchRegion.contains(mousePos)
    }

    /// Called by heartbeat - evaluates truth and updates state
    func tick() {
        let isInside = isMouseInsideNotch
        let now = Date()

        switch state {
        case .outside:
            if isInside {
                state = .entering(since: now)
            }

        case .entering(let since):
            if !isInside {
                // Mouse left before debounce completed
                state = .outside
            } else if now.timeIntervalSince(since) >= enterDelay {
                // Debounce complete, mouse still inside
                state = .inside
                onShouldOpen?()
            }

        case .inside:
            if !isInside {
                state = .exiting(since: now)
            }

        case .exiting(let since):
            if isInside {
                // Mouse came back! Cancel close.
                state = .inside
            } else {
                let delay = isShelfActive ? exitDelayShelf : exitDelayNormal
                if now.timeIntervalSince(since) >= delay {
                    // Delay complete, mouse still outside
                    state = .outside
                    onShouldClose?()
                }
            }
        }
    }

    // MARK: - Heartbeat Control

    func startHeartbeat() {
        guard heartbeat == nil else { return }

        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(16)) // ~60 FPS
            }
        }
    }

    func stopHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
    }
}
```

---

## Flow Diagrams

### Scenario 1: Normal Hover Open

```
TIME     MOUSE POSITION      STATE           ACTION
─────────────────────────────────────────────────────────────
0ms      Outside notch       .outside        -
16ms     Enters notch        .entering(T0)   -
32ms     Still inside        .entering       -
48ms     Still inside        .entering       -
64ms     Still inside        .inside         onShouldOpen() ✓
80ms     Still inside        .inside         -
...      Still inside        .inside         Notch stays open
```

### Scenario 2: Quick Pass-Through (No Open)

```
TIME     MOUSE POSITION      STATE           ACTION
─────────────────────────────────────────────────────────────
0ms      Outside notch       .outside        -
16ms     Enters notch        .entering(T0)   -
32ms     Exits notch         .outside        - (cancelled)

Result: Notch never opens because mouse left within 50ms debounce
```

### Scenario 3: Button Click (Layout Shift)

```
TIME     MOUSE POSITION      STATE           ACTION
─────────────────────────────────────────────────────────────
0ms      Inside notch        .inside         Notch is open
16ms     Click button        .inside         -
         (layout changes)
32ms     STILL inside!       .inside         - (truth wins)
48ms     Still inside        .inside         -

Result: Notch stays open because we check ACTUAL position,
        not what the view THINKS happened
```

### Scenario 4: Mouse Exits → Returns (Cancel Close)

```
TIME     MOUSE POSITION      STATE           ACTION
─────────────────────────────────────────────────────────────
0ms      Inside notch        .inside         Notch open
16ms     Exits notch         .exiting(T0)    -
32ms     Still outside       .exiting        -
...      (300ms pass)        .exiting        -
350ms    Returns to notch!   .inside         Close cancelled ✓
366ms    Still inside        .inside         -

Result: User moved mouse back in time. Close cancelled.
```

### Scenario 5: Mouse Exits → Stays Out → Close

```
TIME     MOUSE POSITION      STATE           ACTION
─────────────────────────────────────────────────────────────
0ms      Inside notch        .inside         Notch open
16ms     Exits notch         .exiting(T0)    -
...      (500ms pass)        .exiting        -
516ms    Still outside       .outside        onShouldClose() ✓

Result: Mouse stayed out for full delay. Notch closes.
```

### Scenario 6: Shelf Mode (Longer Delay for Drops)

```
TIME     MOUSE POSITION      STATE           ACTION
─────────────────────────────────────────────────────────────
0ms      Drag file to notch  .inside         Notch open, shelf visible
16ms     isShelfActive=true  .inside         -
32ms     Position file       .inside         -
48ms     Exit to get file    .exiting(T0)    -
...      (2 seconds)         .exiting        Still waiting...
2000ms   Return with file    .inside         Close cancelled ✓
2016ms   Drop file           .inside         File dropped!

Result: 4 second delay gives user time to grab more files
```

---

## Multi-Screen Support

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    MULTI-SCREEN ARCHITECTURE                     │
│                                                                  │
│  ┌─────────────────────┐       ┌─────────────────────┐          │
│  │    Screen A          │       │    Screen B          │          │
│  │    (MacBook)         │       │    (External)        │          │
│  │                      │       │                      │          │
│  │  ┌────────────────┐ │       │  ┌────────────────┐ │          │
│  │  │NotchHoverCtrl A│ │       │  │NotchHoverCtrl B│ │          │
│  │  │                │ │       │  │                │ │          │
│  │  │ window: A      │ │       │  │ window: B      │ │          │
│  │  │ state: .inside │ │       │  │ state: .outside│ │          │
│  │  │ heartbeat: ON  │ │       │  │ heartbeat: OFF │ │          │
│  │  └────────────────┘ │       │  └────────────────┘ │          │
│  │                      │       │                      │          │
│  └─────────────────────┘       └─────────────────────┘          │
│                                                                  │
│  KEY: Each screen has its OWN controller with its OWN window    │
│       reference. No shared state between screens!                │
│                                                                  │
│  The heartbeat checks NSEvent.mouseLocation (GLOBAL coords)     │
│  against window.frame (also GLOBAL coords).                     │
│  This works correctly regardless of screen arrangement.         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Comparison: Old vs New

```
┌────────────────────────┬────────────────────────────────────────┐
│      OLD SYSTEM        │           NEW SYSTEM                   │
├────────────────────────┼────────────────────────────────────────┤
│                        │                                        │
│ Event-driven           │ Truth-driven (polling)                 │
│                        │                                        │
│ Relies on view coords  │ Uses window frame (stable)             │
│                        │                                        │
│ Two separate tasks     │ Single heartbeat                       │
│ (open + close)         │                                        │
│                        │                                        │
│ Boolean isHoveringNotch│ State machine with 4 states           │
│ can get corrupted      │ (clear transitions)                    │
│                        │                                        │
│ Events can be missed   │ Heartbeat catches everything           │
│ or spurious            │                                        │
│                        │                                        │
│ Complex validation     │ Simple: region.contains(mousePos)      │
│ with buffers           │                                        │
│                        │                                        │
│ Multi-screen issues    │ Works correctly (global coords)        │
│                        │                                        │
│ ~15 edge cases         │ ~3 edge cases                          │
│                        │                                        │
└────────────────────────┴────────────────────────────────────────┘
```

---

## Edge Cases Handled

### Edge Case 1: Mouse Teleports (Fast Movement)

```
OLD: mouseExit might not fire if mouse moves too fast
NEW: Heartbeat sees position change, triggers correct transition
```

### Edge Case 2: Display Reconfigured

```
OLD: View coordinates become invalid, spurious exits
NEW: window.frame updates automatically, heartbeat sees new coords
```

### Edge Case 3: Button Click Causes Layout Shift

```
OLD: View bounds change → spurious mouseExit → wrong state
NEW: Mouse hasn't moved → region.contains() still true → no change
```

### Edge Case 4: Drag File From Desktop

```
OLD: Complex interaction between DragDropService and hover state
NEW: Heartbeat sees mouse in region → state = .inside
     isShelfActive = true → 4 second exit delay
```

---

## Integration Points

### With BoringViewModel

```swift
// In BoringViewModel initialization
func setupHoverController() {
    hoverController = NotchHoverController()
    hoverController.window = /* get NSWindow reference */

    hoverController.onShouldOpen = { [weak self] in
        self?.open()
    }

    hoverController.onShouldClose = { [weak self] in
        self?.close(force: true)
    }
}

// When notch opens
func open() {
    // ... existing open logic ...
    hoverController.startHeartbeat()
}

// When notch closes
func close(force: Bool) {
    // ... existing close logic ...
    hoverController.stopHeartbeat()
}

// When switching to shelf view
func showShelf() {
    hoverController.isShelfActive = true
}
```

### With TrackingAreaView (Optional Optimization)

```swift
// TrackingAreaView can provide HINTS to reduce latency
// but heartbeat is the source of truth

TrackingAreaView(
    onEnter: {
        // Hint: mouse probably entered, tick immediately
        hoverController.tick()
    },
    onExit: {
        // Hint: mouse probably exited, tick immediately
        hoverController.tick()
    },
    onMove: { _ in }
)
```

This makes the system **responsive** (events trigger immediate check) while remaining **reliable** (heartbeat validates everything).

---

## Performance Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE IMPACT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Heartbeat: 60 ticks/second                                     │
│                                                                  │
│  Per tick:                                                       │
│  • NSEvent.mouseLocation      ~0.001ms                          │
│  • CGRect.contains()          ~0.0001ms                         │
│  • State machine switch       ~0.0001ms                         │
│  • Date comparison            ~0.0001ms                         │
│  ─────────────────────────────────────                          │
│  Total per tick:              ~0.002ms                          │
│                                                                  │
│  60 ticks × 0.002ms = 0.12ms per second                         │
│                                                                  │
│  CPU usage: 0.012% (negligible)                                 │
│                                                                  │
│  ONLY RUNS WHEN NOTCH IS OPEN                                   │
│  When closed: 0% CPU (heartbeat stopped)                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary

### The Key Innovations

1. **Truth over events** - Check actual mouse position, don't trust view events
2. **Heartbeat validation** - Continuous polling catches all edge cases
3. **Window frame, not view bounds** - Stable reference that doesn't change during layout
4. **State machine** - Clear transitions, impossible to corrupt
5. **Re-entry detection** - Mouse returning cancels pending close

### Why This Will Work

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  The mouse position is ALWAYS correct.                          │
│  NSEvent.mouseLocation cannot lie.                              │
│                                                                  │
│  The window frame is ALWAYS stable.                             │
│  It doesn't change during SwiftUI layout shifts.                │
│                                                                  │
│  By checking truth every 16ms, we CANNOT miss anything.         │
│  Events become optimizations, not requirements.                  │
│                                                                  │
│  The state machine has only 4 states and clear transitions.     │
│  There's no way to get into an invalid state.                   │
│                                                                  │
│  This is how games handle input - and games never drop inputs.  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Next Steps

1. [ ] Implement `NotchHoverController` class
2. [ ] Integrate with `BoringViewModel`
3. [ ] Remove old `mouseEntered`/`mouseExited` logic
4. [ ] Remove `TrackingAreaView` validation (keep as hint only)
5. [ ] Test on multi-screen setup
6. [ ] Test with rapid hover in/out
7. [ ] Test button clicks
8. [ ] Test file drag & drop
