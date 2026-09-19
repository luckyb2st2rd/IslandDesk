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

## Next

1. Add fullscreen detection and the default hide-in-fullscreen policy.
2. Replace the generated tray/application icon with branded assets.
3. Add media-session selection when several players are active.

## Verification

The Windows workstation passes `flutter analyze`, eighteen Flutter widget/controller/layout/persistence/media tests, a Windows Flutter-Rust integration test, `cargo fmt --all --check`, strict Clippy and fourteen Rust workspace tests using the MSVC linker. The integration test opens the real Windows GSMTC manager, receives its first native stream event, and avoids mutating an active user session. The release executable is smoke-tested through media initialization and its tray lifecycle.
