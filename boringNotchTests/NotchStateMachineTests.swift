//
//  NotchStateMachineTests.swift
//  boringNotchTests
//
//  Unit tests for NotchStateMachine.
//  Tests state computation logic extracted from ContentView.
//

import XCTest
@testable import boringNotch

final class NotchStateMachineTests: XCTestCase {

    // MARK: - Test Fixtures

    func makeDefaultInput() -> NotchStateInput {
        NotchStateInput(
            notchState: .closed,
            currentView: .home,
            helloAnimationRunning: false,
            sneakPeek: sneakPeek(show: false, type: .music, value: 0.0, icon: ""),
            expandingView: ExpandedItem(show: false, type: .battery, value: 0, icon: ""),
            musicLiveActivityEnabled: true,
            isPlaying: false,
            isPlayerIdle: true,
            hideOnClosed: false,
            showNotHumanFace: false,
            showPowerStatusNotifications: true,
            inlineHUD: false,
            hudReplacement: false
        )
    }

    // MARK: - Hello Animation Tests

    func testHelloAnimationState() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.helloAnimationRunning = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .helloAnimation)
    }

    // MARK: - Open State Tests

    func testOpenStateShowsCurrentView() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .shelf

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .shelf))
    }

    // MARK: - Closed State Tests

    func testClosedIdleState() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .idle))
    }

    func testMusicLiveActivityWhenPlaying() {
        var settings = MockNotchSettings()
        settings.musicLiveActivityEnabled = true

        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = true
        input.isPlayerIdle = false
        input.musicLiveActivityEnabled = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .musicLiveActivity))
    }

    func testBatteryNotificationState() {
        var settings = MockNotchSettings()
        settings.showPowerStatusNotifications = true

        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .closed
        input.expandingView = ExpandedItem(show: true, type: .battery, value: 100, icon: "battery.100")
        input.showPowerStatusNotifications = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .batteryNotification))
    }

    func testFaceStateWhenEnabled() {
        var settings = MockNotchSettings()
        settings.showNotHumanFace = true

        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .closed
        input.showNotHumanFace = true

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .face))
    }

    // MARK: - Sneak Peek Tests

    func testSneakPeekOverlayForNonMusicType() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = sneakPeek(show: true, type: .brightness, value: 0.5, icon: "sun.max")

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek(let type, let value, _) = content {
                XCTAssertEqual(type, .brightness)
                XCTAssertEqual(value, 0.5, accuracy: 0.01)
            } else {
                XCTFail("Expected sneakPeek content")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    // MARK: - Inline HUD Tests

    func testInlineHUDState() {
        var settings = MockNotchSettings()
        settings.showInlineHUD = true

        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .closed
        input.expandingView = ExpandedItem(show: true, type: .volume, value: 0.75, icon: "speaker.wave.3")
        input.inlineHUD = true

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .inlineHUD(let type, let value, _) = content {
                XCTAssertEqual(type, .volume)
                XCTAssertEqual(value, 0.75, accuracy: 0.01)
            } else {
                XCTFail("Expected inlineHUD content, got \(content)")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    // MARK: - Priority Tests

    func testHelloAnimationHasPriority() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        // Everything is enabled, but hello animation should take priority
        var input = makeDefaultInput()
        input.helloAnimationRunning = true
        input.notchState = .open
        input.isPlaying = true
        input.sneakPeek = sneakPeek(show: true, type: .volume, value: 0.5, icon: "")

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .helloAnimation)
    }

    func testOpenStateOverridesClosedContent() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .notifications
        input.isPlaying = true  // Would normally show music

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .notifications))
    }

    // MARK: - Chin Width Computation Tests

    func testChinWidthForBatteryNotification() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        // Manually set state to battery notification
        stateMachine.transition(to: .closed(content: .batteryNotification))

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: 200,
            displayClosedNotchHeight: 32
        )

        XCTAssertEqual(chinWidth, 640)
    }

    func testChinWidthForMusicLiveActivity() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

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

    func testChinWidthForIdleState() {
        let settings = MockNotchSettings()
        let stateMachine = NotchStateMachine(settings: settings)

        stateMachine.transition(to: .closed(content: .idle))

        let baseWidth: CGFloat = 200
        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: 32
        )

        XCTAssertEqual(chinWidth, baseWidth)
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
