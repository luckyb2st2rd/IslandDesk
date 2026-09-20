# Development status

## Completed

- Monorepo, CI and privacy baseline.
- Windows development toolchain: Flutter, Dart, Rust, MSVC Build Tools and Windows SDK.
- Flutter application shell and Windows-oriented visual prototype.
- Animated `Collapsed`, `Peek`, `Expanded` and hidden/transient state sizing.
- Deterministic Island state transitions in Dart and Rust.
- Controller and widget test coverage for the first interactions.
- Generated Flutter Windows runner and desktop plugin registration.
- Transparent, frameless, always-on-top window shell.
- Primary-monitor top-center positioning and state-driven native sizing.
- Windows release build validation in GitHub Actions.
- System tray with show, settings and explicit exit actions.
- Close-to-tray lifecycle that keeps the background process running.
- Settings shell with live animation and always-on-top controls.
- Versioned SQLite settings schema in the platform application-support directory.
- Serialized settings writes that are flushed before an explicit tray exit.
- Generated `flutter_rust_bridge` bindings backed by Flutter Native Assets.
- Application-startup initialization and typed Flutter-to-Rust runtime status call.
- Windows desktop integration test that loads and calls the packaged Rust library.
- Rust-owned monitor selection policy with primary fallback.
- DPI-aware top-center positioning in logical display coordinates.
- Primary, follow-active and fixed-monitor settings persisted in SQLite schema v2.
- Display topology refresh and a 400 ms follow-active monitor tracking delay.
- Platform-neutral Rust `MediaService` contract and media domain model.
- Isolated Windows GSMTC adapter with explicit WinRT apartment lifetime.
- Typed Flutter-Rust APIs for current session and Play/Pause/Next/Previous.
- Island media metadata, playback progress and capability-aware controls.
- Native GSMTC manager/session event stream with non-fatal error handling and automatic subscription cleanup.
- Bounded media artwork transfer from WinRT to Flutter with a resilient fallback icon.
- Seek support and locally extrapolated playback progress without Windows polling.
- Human-friendly source application labels derived from Windows application identifiers.
- Win32 foreground fullscreen detection based on client and monitor bounds.
- Persisted, default-on hide-in-fullscreen policy with tray-safe restoration.
- Persisted, default-on desktop auto-hide with a narrow top-center reveal zone.
- Native window hiding 1.5 seconds after the pointer leaves the Island.
- Scrollable module navigation for Media, File Shelf, Clipboard, Timer, Notes, App Launcher and System Controls.
- Encrypted, debounced Quick Notes persistence in a dedicated SQLite repository.
- Persistent countdown state with absolute deadlines that recover correctly after restart, window hiding and system sleep.
- Platform-neutral Rust contracts for audio endpoints and Keep Awake.
- Native Windows Core Audio output volume, speaker mute and microphone mute controls.
- Dedicated-thread Windows Keep Awake lifecycle that is cleared on disable or application exit.
- System Controls Flutter UI with external-state refresh and non-fatal device/error handling.
- Native File Shelf drag-in from desktop file managers through a cross-platform drop target.
- Dedicated SQLite File Shelf metadata repository with duplicate suppression and startup restore.
- File Shelf pin/remove actions that never modify the original file.
- Cross-application File Shelf drag-out with copy-only native file URI payloads.
- File Shelf missing-file detection, manual availability refresh and replacement-path relinking.
- Authenticated AES-256-GCM clipboard payload encryption in Rust Core.
- Windows Credential Manager key creation/loading without exposing key bytes to Flutter.
- Typed bridge readiness status and a protected/disabled Clipboard UI indicator.
- Event-driven Windows text clipboard listener using `AddClipboardFormatListener` and a message-only window.
- Dedicated Clipboard SQLite repository that stores nonce and authenticated ciphertext only.
- Clipboard history duplicate suppression, 20,000-character safety bound and 50-item unpinned retention limit.
- Clipboard copy, pin, remove and clear-unpinned actions with corrupt-record quarantine.
- Persisted Clipboard capture pause/resume control.
- Foreground-process attribution and configurable sensitive-application exclusions applied before persistence.
- Heartbeat separation and startup behavior that avoids importing stale pre-existing clipboard content.

## Next

1. Add launcher persistence and global hotkeys.
2. Add Windows audio-device selection after the documented endpoint-switching policy is finalized.
3. Stabilize Linux adapters after the Windows contracts are complete.

## Verification

The Windows workstation passes `flutter analyze`, forty Flutter widget/controller/layout/persistence/media/fullscreen/auto-hide/File Shelf/Clipboard/productivity/system-control tests, a Windows Flutter-Rust integration test, `cargo fmt --all --check`, strict Clippy and twenty-four Rust workspace tests using the MSVC linker. The integration test opens the real Windows GSMTC manager, receives its first native media and clipboard stream events, exercises foreground fullscreen detection and Keep Awake activation/cleanup, and verifies Credential Manager-backed encryption round-trip without reading or logging key material. The release executable is smoke-tested through native service initialization, its tray lifecycle and native auto-hide behavior.
