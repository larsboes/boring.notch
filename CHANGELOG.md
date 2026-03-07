# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 🏗 Architecture Overhaul (Plugin System)
Completion of massive architectural refactoring ("Phase 5"). Monolithic singleton-based design → modular, plugin-first architecture.

*   **Plugin Engine**: `PluginManager` + `NotchPlugin` protocol.
*   **Everything is a Plugin**: All core features (Music, Battery, Calendar, Shelf, Weather, Webcam) migrated to standalone plugins in `Plugins/BuiltIn/`.
*   **Service Container**: Replaced scattered singletons with unified `ServiceContainer` for DI.
*   **Testability**: All services use protocols (`MusicServiceProtocol`, etc.), enabling mock injection.

### ✨ New Features
*   **Teleprompter Pro**: Full-featured teleprompter with countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text assist (refine/summarize/draft via Ollama), control panel with speed/font/color.
*   **Browser Extension**: Safari web extension for media control from the notch.
*   **Habit Tracker Plugin**: Daily habit tracking with streaks, progress rings, persistent storage.
*   **Pomodoro Plugin**: Focus timer with work/break intervals, session history, notch-integrated controls.
*   **Display Surface Plugin**: Generic display arbitration for surfacing prioritized content.
*   **Notifications Plugin**: Dedicated system notification handling.
*   **Clipboard Plugin**: Clipboard history management from the notch.
*   **AI Subsystem**: `AIManager` + `AIProvider` protocol with Ollama backend for text generation.
*   **Local API Server**: HTTP + WebSocket server for external integrations (`notchctl` CLI, browser extension). Auth middleware, rate limiting, plugin API routes.
*   **App Intents & URL Scheme**: Siri Shortcuts integration + `boringnotch://` URL scheme handler.
*   **Protocol-Based Services**: Clean APIs enabling easy provider swaps.

### 🐛 Bug Fixes
*   **XPC Helper**: Fixed IOServicePort leak in brightness check; broke retain cycle in connection invalidation handler.
*   **Animation**: Fixed album art ghost on track change, smoother closing animation, shell-first open/close timeline.
*   **Settings**: Reverted `bindableSettings` fatalError — SwiftUI resolves default before env modifier applies.
*   **DI**: Added missing `@Environment(\.settings)` and Combine imports post-refactor.
*   **Home View**: Default to home view on notch open instead of shelf.

### 🧹 Tech Debt & Improvements
*   **Singleton Removal**: 300+ `.shared` sites removed. Views use `@Environment` or init injection.
*   **Modern State Management**: Migrated to Swift 5.9 `@Observable` macro across all core models.
*   **Decoupled Settings**: Split `DefaultsNotchSettings` into focused extensions (+Display, +HUD, +Music, +Plugins). No direct `Defaults[.]` outside settings files.
*   **File Structure**: `Core/` for domain + coordination, `Plugins/` for features, `UI/` for view helpers.
*   **Apple-quality animations**: Content reveal modifier, shadow easing, spring-tuned choreography.
*   **Architecture gate CI**: Automated boundary violation checks.

### 🏛 SOLID & DDD Hardening
Comprehensive review and refactoring across 34+ files.

#### SRP Extractions
*   **TeleprompterTimerManager**: Timer + mic monitor lifecycle extracted from `TeleprompterState`.
*   **TeleprompterScrollEngine / ShortcutHandler / CountdownState**: Further SRP splits.
*   **DisplayPrioritizer**: Display arbitration extracted from `PluginManager` into pure struct.
*   **HeaderButton / HeaderActionButton**: Reusable components from `BoringHeader` (197→130 lines).
*   **ContentView sub-views**: `notchBackground`, `glassOverlay`, `topEdgeLine` extracted.

#### DDD Improvements
*   **PluginID enum**: 30+ stringly-typed identifiers → type-safe constants. Typos are compile errors.
*   **SneakContentType.isHUD**: Moved to computed property on domain enum.
*   **NotchServiceProvider**: Protocol for clean service resolution across plugin boundaries.

#### Clean Code
*   **DisplaySurfaceState**: Private `ttlTask`, `[weak self]` capture, explicit `clear()`.
*   **Named constants**: Magic numbers extracted across teleprompter state.
*   **SpotifyController.setFavorite()**: LSP contract documented.
