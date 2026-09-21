# Architecture decisions

## Platform order

1. Windows 10/11 is the implementation and release priority.
2. Linux adapters follow after the Windows domain contracts are stable. X11 and Wayland are separate targets.
3. macOS follows without moving platform logic into Flutter UI.

## Layering

The Rust core owns domain models, service contracts, domain database access, event publication and error mapping. `platform/*` implements the contracts. Flutter consumes typed bridge APIs and renders state. The Flutter shell may persist non-sensitive presentation preferences, such as animation and window behavior, behind a replaceable repository interface.

`flutter_rust_bridge` generates the Dart and Rust FFI boundary. Flutter Native Assets builds and bundles the native library for the selected desktop target. Public bridge functions live under `rust/crates/bridge/src/api`; generated files are committed so API drift is reviewable.

Monitor selection is split at a deliberate platform boundary. Rust Core owns the `Primary`, `FollowActive`, and `Fixed` selection/fallback policy. Flutter's desktop adapter enumerates displays through `screen_retriever`, keeps coordinates in logical pixels, and applies the selected work-area position through `window_manager`. A disconnected fixed monitor falls back to primary without discarding the saved monitor ID.

Media integration follows the service-adapter boundary. `islanddesk-core` defines media session, capability, command and error types. `islanddesk-platform-windows` is the only crate that calls WinRT Global System Media Transport Controls and initializes a WinRT apartment. It owns bounded artwork reads, seek conversion and manager/session event subscriptions. `islanddesk-bridge` maps the domain model and native event stream into generated Dart types. The Flutter media controller converts platform failures into non-fatal UI state and locally extrapolates playback progress between native timeline events without polling Windows or logging media metadata.

System controls use the same boundary. Rust Core defines audio and Keep Awake contracts. The Windows adapter owns Core Audio COM endpoint access and balances the COM apartment for every operation. Output volume, output mute and input mute target the current default multimedia endpoints. Keep Awake owns a dedicated native thread for the full request lifetime because `SetThreadExecutionState` is thread-scoped; disabling the feature or exiting IslandDesk clears the request.

Application launching also remains behind a platform-neutral Rust contract. Flutter persists only user-selected launch metadata and ordering, while the Windows adapter validates the target and delegates execution to `ShellExecuteW`. The launcher never scans installed applications or executes an unselected path implicitly.

Global shortcut registration is also isolated behind the bridge. Rust Core defines the persisted shortcut vocabulary, while the Windows adapter owns a message-only window, `RegisterHotKey` lifecycle, conflict reporting and live reconfiguration. A low-frequency status heartbeat releases native registration after the Flutter stream is cancelled. Flutter only selects a supported shortcut and turns activation events into the same explicit show-Island action used by the tray.

Clipboard security follows the same boundary. Rust Core owns AES-256-GCM authenticated encryption, uses a fresh 96-bit nonce for every payload and binds each ciphertext to its record identifier as associated data. The Windows adapter loads or creates the 256-bit key in Windows Credential Manager and captures text through an event-driven message-only window registered with `AddClipboardFormatListener`. Each real update includes only the foreground executable filename so the controller can reject configured sensitive applications before encryption or persistence; heartbeat events carry no new capture semantics, and pre-existing clipboard content is not imported at startup. Flutter receives accepted clipboard text only for the local UI/controller and hands it straight back to Rust for encryption; the key never crosses the bridge. SQLite stores only nonce, ciphertext and non-sensitive record metadata. Clipboard history remains disabled when secure key initialization fails, while pause and exclusion preferences persist locally.

Fullscreen detection uses the same boundary. Rust Core owns rectangle coverage semantics, while the Windows adapter reads the foreground window client bounds and its nearest monitor through Win32. Flutter performs a serialized 500 ms status check and applies a separate visibility policy, so automatic suppression never overrides an explicit close-to-tray action. The settings view is not suppressed, allowing the user to change the policy while another application remains fullscreen.

Normal desktop visibility uses a separate auto-hide input in that policy. While the native window is hidden, a low-frequency Flutter desktop controller observes only a 220 x 4 logical-pixel activation zone at the top center of the selected monitor. Entering the zone reveals the existing window; leaving the Island schedules native window hiding after 1.5 seconds. Fullscreen, auto-hide and explicit tray visibility remain independent so one source cannot accidentally reverse another.

## Storage boundaries

- Flutter SQLite contains shell preferences only and lives in the operating system application-support directory.
- Rust persistence remains the target for shared domain records. Current File Shelf, Clipboard, productivity and App Launcher vertical slices use dedicated SQLite repositories behind replaceable Dart interfaces so they can migrate without changing UI/controller contracts. Clipboard and Quick Notes rows contain Rust-produced authenticated ciphertext, never plaintext; timer and launcher metadata contain no note or clipboard content.
- Clipboard contents, notes, filenames and other user data must never be added to the shell-preferences database.
- Sensitive persistent data requires encryption and operating-system credential storage before implementation.

## Initial scope

The first vertical slice is the island shell, including state transitions, system tray, settings shell, persistent settings and multi-monitor positioning. The second slice adds Windows media metadata and transport commands. The expanded module navigation now exposes all seven product sections. File Shelf provides native drag-in and cross-application drag-out, deduplication, reference-only persistence, pinning, missing-file detection, relinking and metadata-only removal. Clipboard History provides event-driven Windows capture, encrypted persistence, retention, pinning, deletion, pause and source-application exclusions. Quick Notes use authenticated local encryption, while the timer persists an absolute deadline and derives remaining time from the wall clock instead of trusting periodic UI ticks.
