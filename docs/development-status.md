# Development status

## Completed

- Monorepo, CI and privacy baseline.
- Windows development toolchain: Flutter, Dart, Rust, MSVC Build Tools and Windows SDK.
- Flutter application shell and Windows-oriented visual prototype.
- Animated `Collapsed`, `Peek`, `Expanded` and hidden/transient state sizing.
- Deterministic Island state transitions in Dart and Rust.
- Controller and widget test coverage for the first interactions.

## Next

1. Generate the Windows and Linux Flutter runner projects.
2. Add transparent, borderless, always-on-top window behavior on Windows.
3. Add system tray lifecycle and a settings window.
4. Configure `flutter_rust_bridge` code generation.
5. Implement `MonitorService` and Windows DPI positioning.
6. Add SQLite settings persistence.

## Verification

The Windows workstation passes `flutter analyze`, Flutter widget/controller tests, `cargo fmt --check`, and the Rust workspace tests using the MSVC linker.
