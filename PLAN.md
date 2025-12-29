# Calendar Widget Rebuild Plan

## Problem
1. Calendar not showing - `showCalendar` defaults to `false` in `Constants.swift:149`
2. Current design uses scrollable 21-day WheelPicker, doesn't match reference

## Goal
Match reference design: fixed 6-day week view (Mon-Sat) with compact styling

## Implementation Steps

### Step 1: Create WeekDayPicker Component
Replace `WheelPicker` in `BoringCalendar.swift` with new `WeekDayPicker`:
- Fixed 6-day display (Mon-Sat of current week)
- Day name abbreviations above date numbers
- Today: blue circle (`Color.effectiveAccent`)
- Selected: subtle gray background

```swift
struct WeekDayPicker: View {
    @Binding var selectedDate: Date

    private var weekDays: [Date] {
        // Calculate Mon-Sat of current week
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                dayColumn(for: date)  // VStack: day abbrev + date circle
            }
        }
    }
}
```

### Step 2: Update CalendarView Layout
Modify `CalendarView` in `BoringCalendar.swift`:
- Month/Year stacked on left
- WeekDayPicker on right (remove gradient overlays)
- Keep EmptyEventsView and EventListView below

### Step 3: Polish EmptyEventsView
- Already has correct structure (icon + "No events today" + "Enjoy your free time!")
- Minor spacing tweaks if needed

### Step 4: Clean Up Old Code
Delete from `BoringCalendar.swift`:
- `Config` struct (lines 11-19)
- `WheelPicker` struct (lines 21-178)
- Gradient overlays (lines 200-212)

### Step 5: Enable Calendar
Either:
- Change default to `true` in Constants.swift for testing
- Or: Settings > Calendar > Toggle ON

## Files to Modify
| File | Changes |
|------|---------|
| `boringNotch/components/Calendar/BoringCalendar.swift` | Replace WheelPicker, update CalendarView |
| `boringNotch/models/Constants.swift` | Optional: change default to `true` |

## Design Constants
| Element | Value |
|---------|-------|
| Today circle | `Color.effectiveAccent` |
| Selected bg | `Color(white: 0.2)` |
| Primary text | `.white` |
| Secondary text | `Color(white: 0.65)` |
| Day abbrev font | `.caption2` |
| Date number font | `.system(size: 13, weight: .medium)` |

## Decision
Calendar will be **enabled by default** after rebuild (change default from `false` to `true` in Constants.swift).
