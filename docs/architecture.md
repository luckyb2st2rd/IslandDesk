# Architecture decisions

## Platform order

1. Windows 10/11 is the implementation and release priority.
2. Linux adapters follow after the Windows domain contracts are stable. X11 and Wayland are separate targets.
3. macOS follows without moving platform logic into Flutter UI.

## Layering

The Rust core owns domain models, service contracts, database access, event publication and error mapping. `platform/*` implements the contracts. Flutter consumes typed bridge APIs and renders state only.

## Initial scope

The first vertical slice is the island shell, including state transitions, system tray, settings shell and persistent settings. The first native service is media on Windows. Clipboard persistence is postponed until encrypted storage and application exclusions are implemented.

