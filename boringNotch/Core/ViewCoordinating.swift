//
//  ViewCoordinating.swift
//  boringNotch
//
//  Protocol abstracting BoringViewCoordinator for non-view consumers.
//  Views that need @Bindable still use the concrete type via @Environment.
//  Services, coordinators, and the ViewModel depend on this protocol.
//

import Foundation

/// Contract for coordinator state used by non-view consumers.
/// BoringViewCoordinator conforms to this. Services and coordinators depend
/// on this protocol, never the concrete type.
@MainActor
protocol ViewCoordinating: AnyObject, NotchAnimationStateProviding {
    // MARK: - State (read-write overrides from NotchAnimationStateProviding)
    var helloAnimationRunning: Bool { get set }
    var sneakPeek: SneakPeekState { get set }
    var expandingView: ExpandedItem { get set }

    var currentView: NotchViews { get set }
    var isScrollableViewPresented: Bool { get }
    var selectedScreenUUID: String { get }
    var alwaysShowTabs: Bool { get set }
    var openLastTabByDefault: Bool { get set }
    var firstLaunch: Bool { get set }
    var preferredScreenUUID: String? { get set }

    // MARK: - Actions
    func toggleSneakPeek(status: Bool, type: SneakContentType, duration: TimeInterval, value: CGFloat, icon: String)
    func toggleExpandingView(status: Bool, type: SneakContentType, value: CGFloat, browser: BrowserType)
    func showEmpty()
}
