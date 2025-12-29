//
//  KeyboardShortcutCoordinator.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Extracted from AppDelegate - handles keyboard shortcut registration and actions.
//

import AppKit
import Defaults
import KeyboardShortcuts

/// Coordinates keyboard shortcuts for the notch.
/// Extracted from AppDelegate to improve separation of concerns.
@MainActor
final class KeyboardShortcutCoordinator {
    // MARK: - Properties

    private let coordinator: BoringViewCoordinator
    private let windowCoordinator: WindowCoordinator
    private var closeNotchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        coordinator: BoringViewCoordinator = .shared,
        windowCoordinator: WindowCoordinator
    ) {
        self.coordinator = coordinator
        self.windowCoordinator = windowCoordinator
    }

    // MARK: - Setup

    /// Register all keyboard shortcuts
    func setupKeyboardShortcuts() {
        setupToggleSneakPeekShortcut()
        setupToggleNotchOpenShortcut()
    }

    // MARK: - Toggle Sneak Peek

    private func setupToggleSneakPeekShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleSneakPeek) { [weak self] in
            guard let self = self else { return }
            self.handleToggleSneakPeek()
        }
    }

    private func handleToggleSneakPeek() {
        if Defaults[.sneakPeekStyles] == .inline {
            let newStatus = !coordinator.expandingView.show
            coordinator.toggleExpandingView(status: newStatus, type: .music)
        } else {
            coordinator.toggleSneakPeek(
                status: !coordinator.sneakPeek.show,
                type: .music,
                duration: 3.0
            )
        }
    }

    // MARK: - Toggle Notch Open

    private func setupToggleNotchOpenShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.handleToggleNotchOpen()
            }
        }
    }

    private func handleToggleNotchOpen() async {
        let mouseLocation = NSEvent.mouseLocation
        let viewModel = windowCoordinator.viewModel(at: mouseLocation)

        closeNotchTask?.cancel()
        closeNotchTask = nil

        switch viewModel.notchState {
        case .closed:
            viewModel.open()

            let task = Task { [weak viewModel] in
                do {
                    try await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        viewModel?.close()
                    }
                } catch { }
            }
            closeNotchTask = task

        case .open:
            viewModel.close()
        }
    }

    // MARK: - Cleanup

    func cancelPendingTasks() {
        closeNotchTask?.cancel()
        closeNotchTask = nil
    }
}

// Note: Keyboard shortcut names are defined in Shortcuts/ShortcutConstants.swift
