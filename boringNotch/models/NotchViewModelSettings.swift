//
//  NotchViewModelSettings.swift
//  boringNotch
//
//  Created to replace direct Defaults access in BoringViewModel
//

import Foundation
import Defaults

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

/// Default implementation using Defaults library
struct DefaultNotchViewModelSettings: NotchViewModelSettings {
    var shelfHoverDelay: Double {
        Defaults[.shelfHoverDelay]
    }

    var backgroundImageURL: URL? {
        Defaults[.backgroundImageURL]
    }

    var hideNotchOption: HideNotchOption {
        Defaults[.hideNotchOption]
    }

    var showNotHumanFace: Bool {
        Defaults[.showNotHumanFace]
    }

    var hideTitleBar: Bool {
        Defaults[.hideTitleBar]
    }

    var openNotchOnHover: Bool {
        Defaults[.openNotchOnHover]
    }

    var openShelfByDefault: Bool {
        Defaults[.openShelfByDefault]
    }
}
