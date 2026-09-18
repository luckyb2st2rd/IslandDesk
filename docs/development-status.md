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

## Next

1. Implement the Windows `MediaService` adapter and event stream.
2. Add fullscreen detection and the default hide-in-fullscreen policy.
3. Replace the generated tray/application icon with branded assets.
4. Generate and validate the Linux runner.

## Verification

The Windows workstation passes `flutter analyze`, fourteen Flutter widget/controller/layout/persistence tests, a Windows Flutter-Rust integration test, `cargo fmt --all --check`, and nine Rust workspace tests using the MSVC linker. The release bundle contains `islanddesk_bridge.dll`; the integration test verifies runtime status and monitor fallback through typed Rust calls. The release executable was also smoke-tested after display enumeration and SQLite schema migration.
