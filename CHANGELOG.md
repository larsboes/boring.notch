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
*   **Teleprompter Pro**: Full-featured teleprompter plugin with countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text assist (refine/summarize/draft), control panel with speed/font/color controls.
*   **Browser Extension**: Safari web extension for media control from the notch.
*   **Notifications Plugin**: A new dedicated plugin for handling system notifications.
*   **Clipboard Plugin**: A new plugin to manage clipboard history directly from the notch.
*   **Protocol-Based Services**: Services now expose clean APIs, making it easier to add new features or swap implementations (e.g., swapping Music providers).

### 🧹 Tech Debt & Improvements
*   **Singleton Removal**: Removed over 300+ usage sites of `.shared` singletons in Views. Views now receive dependencies via `@Environment` or init injection.
*   **Modern State Management**: Migrated `NotchStateMachine`, `DownloadWatcher`, and other core models to Swift 5.9's `@Observable` macro for better performance and cleaner syntax.
*   **Decoupled Settings**: Managers no longer read directly from `Defaults`. Settings are injected, making the logic pure and testable.
*   **File Structure**: Reorganized the codebase to clearly separate `Core/` infrastructure from `Plugins/` feature logic.

### 🏛 SOLID & DDD Hardening (2026-03-08)
Comprehensive architecture review and refactoring across 34 files.

#### SRP Extractions
*   **TeleprompterTimerManager**: Timer and microphone monitor lifecycle extracted from `TeleprompterState`. State class now owns only scroll position, config, and domain logic.
*   **DisplayPrioritizer**: Display arbitration logic extracted from `PluginManager` into pure struct. PluginManager delegates via `DisplayPrioritizer.highestPriority(among:)`.
*   **HeaderButton / HeaderActionButton**: Reusable button components extracted from `BoringHeader`, eliminating 5x copy-paste boilerplate. Header reduced from 197 to 130 lines.
*   **ContentView sub-views**: `notchBackground`, `glassOverlay`, `topEdgeLine` extracted from 175-line body.

#### DDD Improvements
*   **PluginID enum**: All 30+ stringly-typed plugin identifiers replaced with centralized `PluginID` constants. Plugins, routers, event emitters, and settings views all use type-safe references. Typos are now compile errors.
*   **SneakContentType.isHUD**: HUD-type check moved from free function in view to computed property on the domain enum.

#### Clean Code
*   **DisplaySurfaceState**: Made `ttlTask` private, added `[weak self]` capture, added explicit `clear()` method.
*   **Named constants**: TeleprompterState magic numbers extracted (`endBuffer`, `speedStep`, `speedMin`, `speedMax`).
*   **SpotifyController.setFavorite()**: LSP contract documented — `supportsFavorite` already guards callers.
