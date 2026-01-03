# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 🏗 Architecture Overhaul (Plugin System)
This release marks the completion of a massive architectural refactoring ("Phase 5"). The application has moved from a monolithic singleton-based design to a modular, plugin-first architecture.

*   **Plugin Engine**: Introduced `PluginManager` and `NotchPlugin` protocol.
*   **Everything is a Plugin**: Migrated all core features (Music, Battery, Calendar, Shelf, Weather, Webcam) into standalone plugins located in `Plugins/BuiltIn/`.
*   **Service Container**: Replaced scattered singletons with a unified `ServiceContainer` for dependency injection.
*   **Testability**: All services now use protocols (`MusicServiceProtocol`, etc.), enabling mock injection for unit tests.

### ✨ New Features
*   **Notifications Plugin**: A new dedicated plugin for handling system notifications.
*   **Clipboard Plugin**: A new plugin to manage clipboard history directly from the notch.
*   **Protocol-Based Services**: Services now expose clean APIs, making it easier to add new features or swap implementations (e.g., swapping Music providers).

### 🧹 Tech Debt & Improvements
*   **Singleton Removal**: Removed over 300+ usage sites of `.shared` singletons in Views. Views now receive dependencies via `@Environment` or init injection.
*   **Modern State Management**: Migrated `NotchStateMachine`, `DownloadWatcher`, and other core models to Swift 5.9's `@Observable` macro for better performance and cleaner syntax.
*   **Decoupled Settings**: Managers no longer read directly from `Defaults`. Settings are injected, making the logic pure and testable.
*   **File Structure**: Reorganized the codebase to clearly separate `Core/` infrastructure from `Plugins/` feature logic.
