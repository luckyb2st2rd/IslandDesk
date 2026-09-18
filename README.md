# IslandDesk

IslandDesk is a Windows-first desktop utility: a compact, interactive top-center panel for media controls, a temporary file shelf, clipboard history, timers, notes, application launchers, and selected system controls.

The product is designed for Windows 10/11 first, Linux second, and macOS after the shared core is stable. It is not intended to copy another product's UI.

## Architecture

```
Flutter UI -> flutter_rust_bridge -> Rust Core -> platform adapters
                                      |- Windows
                                      |- Linux
                                      `- macOS (later)
```

- `app/` - Flutter UI, island state machine and settings UI.
- `rust/` - platform-neutral domain core and native adapters.
- `docs/` - architecture decisions and development notes.
- `.github/` - continuous integration.

The UI must call domain capabilities (for example, `media.playPause`) rather than operating-system APIs directly. Platform implementations live behind Rust service interfaces.

## Prerequisites

- Flutter stable with the Windows and Linux desktop toolchains.
- Rust stable (`rustup`, `cargo`).
- Visual Studio 2022 Build Tools with the Desktop development with C++ workload for Windows builds.

## Bootstrap

The Flutter SDK is not installed in this workspace. Once installed, generate the native Flutter runner projects from the `app` directory:

```powershell
cd app
flutter create --platforms=windows,linux .
flutter pub get
cd ..\rust
cargo test --workspace
```

The first implementation target is the island shell: a borderless, transparent, always-on-top Windows window with `Collapsed` and `Expanded` states, tray control, a settings shell, and SQLite configuration. Native integration begins with `MonitorService` and `MediaService`.

## Privacy baseline

- No cloud account or server is required.
- Never log clipboard payloads, notes, or filenames in production logs.
- Persistent clipboard data must be encrypted, with keys stored in the operating system credential store.

## Status

Initial development scaffold. Windows implementation is the current milestone.

