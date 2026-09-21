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
- `rust/` - platform-neutral domain core, typed bridge and native adapters.
- `docs/` - architecture decisions and development notes.
- `.github/` - continuous integration.

The UI must call domain capabilities (for example, `media.playPause`) rather than operating-system APIs directly. Platform implementations live behind Rust service interfaces.

## Prerequisites

- Flutter stable with the Windows and Linux desktop toolchains.
- Rust stable (`rustup`, `cargo`).
- Visual Studio 2022 Build Tools with the Desktop development with C++ workload for Windows builds.

## Bootstrap

The Windows workstation is configured with Flutter stable, Rust stable and Visual Studio 2022 Build Tools. Windows Developer Mode must be enabled because Flutter desktop plugins use symbolic links. Restore dependencies and verify both workspaces with:

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter test integration_test/simple_test.dart -d windows
flutter build windows --release
cd ..\rust
cargo fmt --all --check
cargo test --workspace
```

The first implementation target is the island shell: a borderless, transparent, always-on-top Windows window with `Collapsed` and `Expanded` states, tray control, a settings shell, SQLite configuration, DPI-aware multi-monitor placement, edge-triggered auto-hide, automatic fullscreen suppression, and a configurable global reveal shortcut. The typed Flutter-Rust bridge is active through Flutter Native Assets. Windows adapters stream native Global System Media Transport Controls changes, expose Core Audio endpoint volume/mute controls, hold Keep Awake requests on a dedicated native thread, register the global shortcut, and launch user-selected applications through the Windows shell.

After changing a public API under `rust/crates/bridge/src/api`, regenerate and format the bindings:

```powershell
cd app
flutter_rust_bridge_codegen generate
cd ..
cargo fmt --manifest-path rust/Cargo.toml --all
```

## Privacy baseline

- No cloud account or server is required.
- Never log clipboard payloads, notes, or filenames in production logs.
- Persistent clipboard data must be encrypted, with keys stored in the operating system credential store.

## Status

Iteration 3 is in progress. The animated Island UI runs in a generated native Windows runner as a transparent, frameless window at the top center of the primary, active, or selected fixed display. The native window is hidden by default, appears from a narrow top-center activation zone or a persisted global shortcut, and hides 1.5 seconds after the pointer leaves. Shortcut conflicts are reported in Settings and the feature can be disabled. The expanded shell exposes Media, File Shelf, Clipboard, Timer, Notes, App Launcher and System sections. Media is backed by Windows GSMTC. File Shelf accepts files from Explorer, persists references and metadata in a dedicated SQLite database, supports native cross-application drag-out, and can relink moved or deleted files without modifying originals. Clipboard History receives native Windows clipboard events and stores only authenticated AES-256-GCM ciphertext in SQLite; its key remains in Windows Credential Manager. Capture can be paused, and updates from configurable sensitive applications are rejected before persistence. The module supports copy, pin, remove and clear-unpinned actions. Quick Notes are encrypted locally with the same operating-system-protected key. Timer state survives restarts and uses an absolute deadline so sleep or a hidden window does not pause elapsed time. System Controls manages default output volume, speaker/microphone mute and a process-scoped Keep Awake request through native Windows services. App Launcher persists user-selected executables and shortcuts, supports drag reordering and launches them through a typed Rust service. Fullscreen suppression remains independent from explicit tray visibility.
