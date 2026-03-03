//
//  NavigationState.swift
//  boringNotch
//
//  Extracted from BoringViewCoordinator — handles navigation state and tab settings observers.
//

import Combine
// Settings-adjacent service: uses Defaults.updates() for reactive settings stream.
// This is an accepted exception — no protocol-based reactive stream alternative exists yet.
import Defaults
import SwiftUI

// MARK: - Navigation State Protocol

@MainActor
protocol NavigationStateProtocol: AnyObject {
    var currentView: NotchViews { get set }
    func showHome()
}

// MARK: - Navigation State

@MainActor
@Observable
final class NavigationState: NavigationStateProtocol {

    // MARK: - Public State

    var currentView: NotchViews = .home

    // MARK: - Dependencies

    private var settings: NotchSettings
    private let isShelfEmpty: () -> Bool

    // MARK: - Init

    init(
        settings: NotchSettings,
        isShelfEmpty: @escaping () -> Bool = { true }
    ) {
        self.settings = settings
        self.isShelfEmpty = isShelfEmpty

        setupSettingsObservers()
    }

    // MARK: - Public Methods

    func showHome() {
        currentView = .home
    }

    // MARK: - Settings Observers

    private func setupSettingsObservers() {
        // Observe changes to alwaysShowTabs
        Task { @MainActor [weak self] in
            for await value in Defaults.updates(.alwaysShowTabs) {
                guard let self = self else { return }
                if !value {
                    // When tabs are hidden, reset to home unless shelf should be default
                    self.settings.openLastTabByDefault = false
                    let shelfEmpty = self.isShelfEmpty()
                    if shelfEmpty || !self.settings.openShelfByDefault {
                        self.currentView = .home
                    }
                }
            }
        }

        // Observe changes to openLastTabByDefault
        Task { @MainActor in
            for await value in Defaults.updates(.openLastTabByDefault) {
                if value {
                    // When openLastTabByDefault is enabled, always show tabs
                    self.settings.alwaysShowTabs = true
                }
            }
        }
    }
}
