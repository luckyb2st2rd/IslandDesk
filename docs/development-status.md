# Development status

## Completed

- Monorepo, CI and privacy baseline.
- Flutter application shell and Windows-oriented visual prototype.
- Animated `Collapsed`, `Peek`, `Expanded` and hidden/transient state sizing.
- Deterministic Island state transitions in Dart and Rust.
- Controller and widget test coverage for the first interactions.

## Next

1. Install the Flutter, Rust and Windows C++ desktop toolchains.
2. Generate the Windows and Linux Flutter runner projects.
3. Add transparent, borderless, always-on-top window behavior on Windows.
4. Add system tray lifecycle and a settings window.
5. Configure `flutter_rust_bridge` code generation.
6. Implement `MonitorService` and Windows DPI positioning.
7. Add SQLite settings persistence.

## Verification limitation

The current workstation does not expose Flutter or Rust executables, so this iteration has been reviewed statically. GitHub Actions will run the declared analysis and test jobs after the changes are pushed.
