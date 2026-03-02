//
//  NotchViewModelSettings.swift
//  boringNotch
//
//  Created to replace direct Defaults access in BoringViewModel
//

import Foundation

/// Protocol for providing settings to BoringViewModel
/// This allows dependency injection and removes direct Defaults access
protocol NotchViewModelSettings {
    var shelfHoverDelay: Double { get }
    var backgroundImageURL: URL? { get }
    var hideNotchOption: HideNotchOption { get }
    var showNotHumanFace: Bool { get }
    var hideTitleBar: Bool { get }
    var openNotchOnHover: Bool { get }
    var openShelfByDefault: Bool { get }
}

/// Default implementation that delegates to a NotchSettings instance
@MainActor
struct DefaultNotchViewModelSettings: NotchViewModelSettings {
    private let source: any NotchSettings

    init(source: any NotchSettings = DefaultsNotchSettings.shared) {
        self.source = source
    }

    var shelfHoverDelay: Double { source.shelfHoverDelay }
    var backgroundImageURL: URL? { source.backgroundImageURL }
    var hideNotchOption: HideNotchOption { source.hideNotchOption }
    var showNotHumanFace: Bool { source.showNotHumanFace }
    var hideTitleBar: Bool { source.hideTitleBar }
    var openNotchOnHover: Bool { source.openNotchOnHover }
    var openShelfByDefault: Bool { source.openShelfByDefault }
}
