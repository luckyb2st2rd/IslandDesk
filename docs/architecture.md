# Architecture decisions

## Platform order

1. Windows 10/11 is the implementation and release priority.
2. Linux adapters follow after the Windows domain contracts are stable. X11 and Wayland are separate targets.
3. macOS follows without moving platform logic into Flutter UI.

## Layering

The Rust core owns domain models, service contracts, domain database access, event publication and error mapping. `platform/*` implements the contracts. Flutter consumes typed bridge APIs and renders state. The Flutter shell may persist non-sensitive presentation preferences, such as animation and window behavior, behind a replaceable repository interface.

`flutter_rust_bridge` generates the Dart and Rust FFI boundary. Flutter Native Assets builds and bundles the native library for the selected desktop target. Public bridge functions live under `rust/crates/bridge/src/api`; generated files are committed so API drift is reviewable.

## Storage boundaries

- Flutter SQLite contains shell preferences only and lives in the operating system application-support directory.
- Rust persistence will own module configuration and domain records.
- Clipboard contents, notes, filenames and other user data must never be added to the shell-preferences database.
- Sensitive persistent data requires encryption and operating-system credential storage before implementation.

## Initial scope

The first vertical slice is the island shell, including state transitions, system tray, settings shell and persistent settings. The first native service is media on Windows. Clipboard persistence is postponed until encrypted storage and application exclusions are implemented.
