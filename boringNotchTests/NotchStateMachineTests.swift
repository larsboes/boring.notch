//
//  NotchStateMachineTests.swift
//  boringNotchTests
//
//  Unit tests for NotchStateMachine.
//  Tests state computation logic extracted from ContentView.
//

import XCTest
@testable import boringNotch

@MainActor
final class NotchStateMachineTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Creates a default input with all options disabled for isolation testing
    func makeDefaultInput() -> NotchStateInput {
        NotchStateInput(
            notchState: .closed,
            currentView: .home,
            helloAnimationRunning: false,
            sneakPeek: sneakPeek(show: false, type: .music, value: 0.0, icon: ""),
            expandingView: ExpandedItem(show: false, type: .battery, value: 0),
            musicLiveActivityEnabled: false,
            isPlaying: false,
            isPlayerIdle: true,
            hideOnClosed: false,
            showPowerStatusNotifications: false,
            showInlineHUD: false,
            showNotHumanFace: false,
            sneakPeekStyle: .standard
        )
    }

    /// Creates a state machine with mock settings for testing
    func makeStateMachine() -> NotchStateMachine {
        let settings = MockNotchSettings()
        return NotchStateMachine(settings: settings)
    }

    // MARK: - Priority 1: Hello Animation Tests

    func testHelloAnimationTakesPriorityOverEverything() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.helloAnimationRunning = true
        // Enable everything else to ensure hello animation takes priority
        input.notchState = .open
        input.isPlaying = true
        input.sneakPeek = sneakPeek(show: true, type: .volume, value: 0.5, icon: "speaker")
        input.expandingView = ExpandedItem(show: true, type: .battery, value: 100)
        input.showPowerStatusNotifications = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .helloAnimation, "Hello animation should have highest priority")
    }

    func testHelloAnimationWhenClosed() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.helloAnimationRunning = true
        input.notchState = .closed

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .helloAnimation)
    }

    // MARK: - Priority 2: Open State Tests

    func testOpenStateShowsCurrentView() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .shelf

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .shelf))
    }

    func testOpenStateWithHomeView() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .home

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .home))
    }

    func testOpenStateWithNotificationsView() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .notifications

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .notifications))
    }

    func testOpenStateWithClipboardView() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .clipboard

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .clipboard))
    }

    func testOpenStateWithNotesView() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .notes

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .notes))
    }

    func testOpenStateOverridesMusicPlaying() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .home
        input.isPlaying = true
        input.musicLiveActivityEnabled = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .home), "Open state should override music live activity")
    }

    // MARK: - Priority 3: Battery Notification Tests

    func testBatteryNotificationWhenEnabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.expandingView = ExpandedItem(show: true, type: .battery, value: 100)
        input.showPowerStatusNotifications = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .batteryNotification))
    }

    func testBatteryNotificationNotShownWhenDisabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.expandingView = ExpandedItem(show: true, type: .battery, value: 100)
        input.showPowerStatusNotifications = false

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .batteryNotification))
    }

    func testBatteryNotificationNotShownWhenNotExpanding() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.expandingView = ExpandedItem(show: false, type: .battery, value: 100)
        input.showPowerStatusNotifications = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .batteryNotification))
    }

    func testBatteryNotificationNotShownForOtherTypes() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.expandingView = ExpandedItem(show: true, type: .volume, value: 0.5)
        input.showPowerStatusNotifications = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .batteryNotification))
    }

    // MARK: - Priority 4: Inline HUD Tests

    func testInlineHUDForVolumeChange() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .volume, value: 0.75, icon: "speaker.wave.3")
        input.showInlineHUD = true

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .inlineHUD(let type, let value, let icon) = content {
                XCTAssertEqual(type, .volume)
                XCTAssertEqual(value, 0.75, accuracy: 0.01)
                XCTAssertEqual(icon, "speaker.wave.3")
            } else {
                XCTFail("Expected inlineHUD content, got \(content)")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    func testInlineHUDForBrightnessChange() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .brightness, value: 0.5, icon: "sun.max")
        input.showInlineHUD = true

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .inlineHUD(let type, let value, _) = content {
                XCTAssertEqual(type, .brightness)
                XCTAssertEqual(value, 0.5, accuracy: 0.01)
            } else {
                XCTFail("Expected inlineHUD content")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    func testInlineHUDNotShownForMusicType() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .music, value: 0.5, icon: "music.note")
        input.showInlineHUD = true

        let state = stateMachine.computeDisplayState(from: input)

        // Music should not trigger inline HUD
        if case .closed(let content) = state {
            if case .inlineHUD = content {
                XCTFail("Music type should not trigger inline HUD")
            }
        }
    }

    func testInlineHUDNotShownForBatteryType() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .battery, value: 0.8, icon: "battery.100")
        input.showInlineHUD = true

        let state = stateMachine.computeDisplayState(from: input)

        // Battery should not trigger inline HUD
        if case .closed(let content) = state {
            if case .inlineHUD = content {
                XCTFail("Battery type should not trigger inline HUD")
            }
        }
    }

    func testInlineHUDNotShownWhenDisabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .volume, value: 0.75, icon: "speaker.wave.3")
        input.showInlineHUD = false

        let state = stateMachine.computeDisplayState(from: input)

        // Should show standard sneakPeek instead
        if case .closed(let content) = state {
            if case .inlineHUD = content {
                XCTFail("Inline HUD should not show when disabled")
            }
        }
    }

    // MARK: - Priority 5: Music Live Activity Tests

    func testMusicLiveActivityWhenPlaying() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = true
        input.isPlayerIdle = false
        input.musicLiveActivityEnabled = true
        input.hideOnClosed = false

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .musicLiveActivity))
    }

    func testMusicLiveActivityWhenNotIdle() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = false  // Paused but not idle
        input.musicLiveActivityEnabled = true
        input.hideOnClosed = false

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .musicLiveActivity))
    }

    func testMusicLiveActivityNotShownWhenDisabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = true
        input.isPlayerIdle = false
        input.musicLiveActivityEnabled = false

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .musicLiveActivity))
    }

    func testMusicLiveActivityNotShownWhenHideOnClosed() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = true
        input.isPlayerIdle = false
        input.musicLiveActivityEnabled = true
        input.hideOnClosed = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .musicLiveActivity))
    }

    func testMusicLiveActivityNotShownWhenExpandingNonMusicType() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = true
        input.isPlayerIdle = false
        input.musicLiveActivityEnabled = true
        input.expandingView = ExpandedItem(show: true, type: .volume, value: 0.5)

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .musicLiveActivity))
    }

    // MARK: - Priority 6: Face Animation Tests

    func testFaceAnimationWhenEnabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = true
        input.showNotHumanFace = true
        input.hideOnClosed = false
        input.expandingView = ExpandedItem(show: false, type: .battery, value: 0)

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .face))
    }

    func testFaceAnimationNotShownWhenPlaying() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = true
        input.isPlayerIdle = false
        input.showNotHumanFace = true
        input.hideOnClosed = false

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .face))
    }

    func testFaceAnimationNotShownWhenDisabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = true
        input.showNotHumanFace = false

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .face))
    }

    func testFaceAnimationNotShownWhenExpanding() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = true
        input.showNotHumanFace = true
        input.expandingView = ExpandedItem(show: true, type: .volume, value: 0.5)

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertNotEqual(state, .closed(content: .face))
    }

    // MARK: - Priority 7: Standard Sneak Peek Tests

    func testStandardSneakPeekForBrightness() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .brightness, value: 0.7, icon: "sun.max")
        input.showInlineHUD = false  // Inline HUD disabled, should show standard sneak peek

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek(let type, let value, let icon) = content {
                XCTAssertEqual(type, .brightness)
                XCTAssertEqual(value, 0.7, accuracy: 0.01)
                XCTAssertEqual(icon, "sun.max")
            } else {
                XCTFail("Expected sneakPeek content, got \(content)")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    func testStandardSneakPeekForMicrophone() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .mic, value: 0.5, icon: "mic")
        input.showInlineHUD = false

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek(let type, _, _) = content {
                XCTAssertEqual(type, .mic)
            } else {
                XCTFail("Expected sneakPeek content")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    // MARK: - Priority 8: Music Sneak Peek Tests

    func testMusicSneakPeekWithStandardStyle() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .music, value: 0, icon: "music.note")
        input.hideOnClosed = false
        input.sneakPeekStyle = .standard

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek(let type, _, _) = content {
                XCTAssertEqual(type, .music)
            } else {
                XCTFail("Expected sneakPeek content for music")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    func testMusicSneakPeekNotShownWithHideOnClosed() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .music, value: 0, icon: "music.note")
        input.hideOnClosed = true
        input.sneakPeekStyle = .standard

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek = content {
                XCTFail("Music sneak peek should not show when hideOnClosed is true")
            }
        }
    }

    // MARK: - Default Idle State Tests

    func testClosedIdleStateWhenNothingActive() {
        let stateMachine = makeStateMachine()

        let input = makeDefaultInput()
        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .idle))
    }

    func testClosedIdleStateWhenPlayerIdle() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = true
        input.musicLiveActivityEnabled = true  // Enabled but player is idle

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .idle))
    }

    // MARK: - Chin Width Computation Tests

    func testChinWidthForBatteryNotification() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .batteryNotification))

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: 200,
            displayClosedNotchHeight: 32
        )

        XCTAssertEqual(chinWidth, 640, "Battery notification should use fixed 640 width")
    }

    func testChinWidthForMusicLiveActivity() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .musicLiveActivity))

        let baseWidth: CGFloat = 200
        let notchHeight: CGFloat = 32
        let expectedWidth = baseWidth + (2 * max(0, notchHeight - 12) + 20)

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: notchHeight
        )

        XCTAssertEqual(chinWidth, expectedWidth)
    }

    func testChinWidthForFace() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .face))

        let baseWidth: CGFloat = 200
        let notchHeight: CGFloat = 32
        let expectedWidth = baseWidth + (2 * max(0, notchHeight - 12) + 20)

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: notchHeight
        )

        XCTAssertEqual(chinWidth, expectedWidth, "Face should use same width as music live activity")
    }

    func testChinWidthForIdleState() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .idle))

        let baseWidth: CGFloat = 200
        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: 32
        )

        XCTAssertEqual(chinWidth, baseWidth, "Idle state should use base width")
    }

    func testChinWidthForOpenState() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .open(view: .home))

        let baseWidth: CGFloat = 200
        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: 32
        )

        XCTAssertEqual(chinWidth, baseWidth, "Open state should use base width")
    }

    func testChinWidthWithZeroNotchHeight() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .musicLiveActivity))

        let baseWidth: CGFloat = 200
        let notchHeight: CGFloat = 0
        // Formula: baseWidth + (2 * max(0, notchHeight - 12) + 20)
        // = 200 + (2 * 0 + 20) = 220
        let expectedWidth = baseWidth + (2 * max(0, notchHeight - 12) + 20)

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: notchHeight
        )

        XCTAssertEqual(chinWidth, expectedWidth)
    }

    func testChinWidthWithSmallNotchHeight() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .musicLiveActivity))

        let baseWidth: CGFloat = 200
        let notchHeight: CGFloat = 10  // Less than 12
        // Formula: baseWidth + (2 * max(0, 10 - 12) + 20)
        // = 200 + (2 * 0 + 20) = 220
        let expectedWidth: CGFloat = 220

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: notchHeight
        )

        XCTAssertEqual(chinWidth, expectedWidth)
    }

    // MARK: - Should Show Sneak Peek Overlay Tests

    func testShouldShowSneakPeekOverlayForSneakPeek() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .sneakPeek(type: .brightness, value: 0.5, icon: "sun.max")))

        XCTAssertTrue(stateMachine.shouldShowSneakPeekOverlay)
    }

    func testShouldShowSneakPeekOverlayForInlineHUD() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .inlineHUD(type: .volume, value: 0.7, icon: "speaker")))

        XCTAssertTrue(stateMachine.shouldShowSneakPeekOverlay)
    }

    func testShouldNotShowSneakPeekOverlayForIdle() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .idle))

        XCTAssertFalse(stateMachine.shouldShowSneakPeekOverlay)
    }

    func testShouldNotShowSneakPeekOverlayForMusicLiveActivity() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .musicLiveActivity))

        XCTAssertFalse(stateMachine.shouldShowSneakPeekOverlay)
    }

    func testShouldNotShowSneakPeekOverlayForOpenState() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .open(view: .home))

        XCTAssertFalse(stateMachine.shouldShowSneakPeekOverlay)
    }

    // MARK: - State Update Tests

    func testUpdatePublishesNewState() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.isPlaying = true
        input.isPlayerIdle = false
        input.musicLiveActivityEnabled = true

        stateMachine.update(with: input)

        XCTAssertEqual(stateMachine.displayState, .closed(content: .musicLiveActivity))
    }

    func testUpdateStoresLastInput() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.currentView = .shelf

        stateMachine.update(with: input)

        XCTAssertNotNil(stateMachine.lastInput)
        XCTAssertEqual(stateMachine.lastInput?.currentView, .shelf)
    }

    func testUpdateDoesNotPublishWhenStateUnchanged() {
        let stateMachine = makeStateMachine()

        let input = makeDefaultInput()

        // Both calls should result in .closed(.idle)
        stateMachine.update(with: input)
        let firstState = stateMachine.displayState

        stateMachine.update(with: input)
        let secondState = stateMachine.displayState

        XCTAssertEqual(firstState, secondState)
    }

    // MARK: - Edge Case Tests

    func testAllSneakContentTypes() {
        let stateMachine = makeStateMachine()
        let types: [SneakContentType] = [.brightness, .volume, .backlight, .mic, .download]

        for type in types {
            var input = makeDefaultInput()
            input.sneakPeek = sneakPeek(show: true, type: type, value: 0.5, icon: "test")
            input.showInlineHUD = false

            let state = stateMachine.computeDisplayState(from: input)

            if case .closed(let content) = state {
                if case .sneakPeek(let resultType, _, _) = content {
                    XCTAssertEqual(resultType, type, "Type \(type) should produce sneakPeek")
                } else {
                    XCTFail("Expected sneakPeek for type \(type)")
                }
            } else {
                XCTFail("Expected closed state for type \(type)")
            }
        }
    }

    func testBatteryLevels() {
        let stateMachine = makeStateMachine()
        let batteryLevels: [CGFloat] = [0, 25, 50, 75, 100]

        for level in batteryLevels {
            var input = makeDefaultInput()
            input.expandingView = ExpandedItem(show: true, type: .battery, value: level)
            input.showPowerStatusNotifications = true

            let state = stateMachine.computeDisplayState(from: input)

            XCTAssertEqual(state, .closed(content: .batteryNotification),
                          "Battery level \(level) should show notification")
        }
    }

    func testVolumeValueRange() {
        let stateMachine = makeStateMachine()
        let values: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for value in values {
            var input = makeDefaultInput()
            input.sneakPeek = sneakPeek(show: true, type: .volume, value: value, icon: "speaker")
            input.showInlineHUD = true

            let state = stateMachine.computeDisplayState(from: input)

            if case .closed(let content) = state {
                if case .inlineHUD(_, let resultValue, _) = content {
                    XCTAssertEqual(resultValue, value, accuracy: 0.001,
                                  "Value \(value) should be preserved")
                } else {
                    XCTFail("Expected inlineHUD for value \(value)")
                }
            } else {
                XCTFail("Expected closed state for value \(value)")
            }
        }
    }
}

// MARK: - Test Helpers

extension NotchStateMachineTests {

    func assertClosedContent(
        _ state: NotchDisplayState,
        equals expected: NotchDisplayState.ClosedContent,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if case .closed(let content) = state {
            XCTAssertEqual(content, expected, file: file, line: line)
        } else {
            XCTFail("Expected closed state, got \(state)", file: file, line: line)
        }
    }
}
