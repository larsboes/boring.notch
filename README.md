<h1 align="center">
  <br>
  <a href="http://theboring.name"><img src="https://framerusercontent.com/images/RFK4vs0kn8pRMuOO58JeyoemXA.png?scale-down-to=256" alt="Boring Notch" width="150"></a>
  <br>
  Boring Notch (Extended Fork)
  <br>
</h1>

<p align="center">
  <strong>A community-driven fork of <a href="https://github.com/TheBoredTeam/boring.notch">boring.notch</a> with a modern plugin architecture, integrated community PRs, and clean codebase.</strong>
</p>

<p align="center">
  <img src="https://github.com/TheBoredTeam/boring.notch/actions/workflows/cicd.yml/badge.svg" alt="Build & Test" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/2d5f69c1-6e7b-4bc2-a6f1-bb9e27cf88a8" alt="Demo GIF" />
</p>

---

## What is this fork?

This is an extended fork of [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) — the macOS app that transforms your MacBook's notch into a dynamic control center with music playback, calendar, file shelf, HUD replacements, and more.

This fork takes the original and adds:

### Architecture Overhaul
- **Plugin-first architecture** — every feature is a `NotchPlugin`. Built-in features use the same API that future third-party plugins will use.
- **Protocol-based dependency injection** — zero `.shared` singletons in views/services. Everything injected via `@Environment` or init.
- **`@Observable` + `@MainActor`** throughout — no legacy `ObservableObject`/`@Published`.
- **Clean layer boundaries** — Domain, Application, Infrastructure, Presentation layers with enforced import constraints.
- **Service protocols** for all system integrations (music, battery, calendar, weather, shelf, webcam, notifications, clipboard).

### Integrated Community PRs
Cherry-picked and adapted the best community contributions that were pending on upstream:

| Feature | Original PR |
|---------|-------------|
| Sneak peek duration customization | #897 |
| Auto-disable HUD on disconnected displays | #895 |
| Screen recording live activity | #804 |
| Mood face customization | #798 |
| Clipboard history + note-taking (SQLite-backed) | #788 |
| Animated face with mouse tracking | #751 |

### Additional Improvements
- **Standardized animation system** — `StandardAnimations` enum for consistent open/close/interactive curves
- **Dual hover zones** — separate closed/open hover detection for accurate mouse tracking
- **Heartbeat-based hover** — replaced event-driven hover with a robust heartbeat controller (11 unit tests)
- **Data export** — `ExportablePlugin` protocol with export UI in Settings
- **CI pipeline** — build, test, and architecture checks on every push

---

## System Requirements

- macOS **14 Sonoma** or later
- Apple Silicon or Intel Mac

## Building from Source

### Prerequisites

- **macOS 14 or later**
- **Xcode 16 or later**

### Steps

1. **Clone this fork:**
   ```bash
   git clone https://github.com/larsboes/boring.notch.git
   cd boring.notch
   ```

2. **Resolve packages:**
   ```bash
   xcodebuild -resolvePackageDependencies -project boringNotch.xcodeproj -scheme boringNotch
   ```

3. **Open and run:**
   ```bash
   open boringNotch.xcodeproj
   ```
   Press `Cmd + R` to build and run.

> **Note:** If Xcode shows "Missing package product" errors, close and reopen the project after resolving packages. The CLI resolution works — Xcode's GUI cache is just slow.

---

## Architecture

```
SwiftUI Views -> PluginManager -> NotchPlugin instances -> Service Protocols -> System APIs
```

Every feature is a plugin. Plugins communicate via `PluginEventBus`, never by importing each other. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full reference and [docs/PLUGIN_DEVELOPMENT.md](docs/PLUGIN_DEVELOPMENT.md) for the plugin development guide.

---

## Upstream

This fork tracks [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) as `upstream`. Periodic syncs pull in upstream fixes and features.

For the original project, downloads, Discord, and support, visit the upstream repo.

---

## Acknowledgments

All credit for the original boring.notch concept and implementation goes to [TheBoredTeam](https://github.com/TheBoredTeam). This fork builds on their work.

- **[MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter)** — Now Playing source support for macOS 15.4+
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** — Foundation for the Shelf feature

For a full list of licenses and attributions, see [THIRD_PARTY_LICENSES](./THIRD_PARTY_LICENSES.md).
