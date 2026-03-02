import XCTest
@testable import boringNotch

// MARK: - Test Doubles

@MainActor
final class MockHoverZoneChecker: HoverZoneChecking {
    var mouseInZone: Bool = false
    func updateHoverZone(screenUUID: String?) {}
    func isMouseInHoverZone() -> Bool { mouseInZone }
}

struct MockNotchViewModelSettings: NotchViewModelSettings {
    var shelfHoverDelay: Double = 1.0
    var backgroundImageURL: URL? = nil
    var hideNotchOption: HideNotchOption = .never
    var showNotHumanFace: Bool = false
    var hideTitleBar: Bool = false
    var openNotchOnHover: Bool = true
    var openShelfByDefault: Bool = false
}

// MARK: - Tests

@MainActor
final class NotchHoverControllerTests: XCTestCase {

    func testDebounce_mouseQuickPassthrough_doesNotOpen() async throws {
        let hoverChecker = MockHoverZoneChecker()
        let controller = NotchHoverController(
            settings: MockNotchViewModelSettings(),
            hoverZoneManager: hoverChecker
        )
        var openCalled = false
        hoverChecker.mouseInZone = true

        controller.handleHoverSignal(.entered, currentPhase: .closed, sneakPeekActive: false, onOpen: { openCalled = true })
        try await Task.sleep(for: .milliseconds(30))

        // Exit before the 50ms open delay fires
        hoverChecker.mouseInZone = false
        controller.handleHoverSignal(.exited, currentPhase: .closed, sneakPeekActive: false, onOpen: {})
        try await Task.sleep(for: .milliseconds(60)) // Past open delay

        XCTAssertFalse(openCalled, "Open should not fire for quick passthrough")
    }

    func testDebounce_mouseStaysInside_opens() async throws {
        let hoverChecker = MockHoverZoneChecker()
        let controller = NotchHoverController(
            settings: MockNotchViewModelSettings(),
            hoverZoneManager: hoverChecker
        )
        var openCalled = false
        hoverChecker.mouseInZone = true

        controller.handleHoverSignal(.entered, currentPhase: .closed, sneakPeekActive: false, onOpen: { openCalled = true })
        try await Task.sleep(for: .milliseconds(100)) // Past 50ms open delay

        XCTAssertTrue(openCalled, "Open should fire after hover delay")
    }

    func testCancelClose_mouseReturns() async throws {
        let hoverChecker = MockHoverZoneChecker()
        let controller = NotchHoverController(
            settings: MockNotchViewModelSettings(),
            hoverZoneManager: hoverChecker
        )
        var closeCalled = false

        // Schedule a close
        controller.scheduleClose(currentPhase: .open, currentView: .home, onClose: { closeCalled = true })

        // Mouse re-enters before the 700ms close delay expires
        hoverChecker.mouseInZone = true
        controller.handleHoverSignal(.entered, currentPhase: .open, sneakPeekActive: false, onOpen: {})

        try await Task.sleep(for: .milliseconds(800)) // Past close delay

        XCTAssertFalse(closeCalled, "Close should be cancelled by re-entry")
    }
}
