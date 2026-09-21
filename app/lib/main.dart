import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/clipboard/clipboard_controller.dart';
import 'package:islanddesk/clipboard/sqlite_clipboard_repository.dart';
import 'package:islanddesk/desktop/desktop_window_controller.dart';
import 'package:islanddesk/desktop/edge_reveal_controller.dart';
import 'package:islanddesk/desktop/fullscreen_controller.dart';
import 'package:islanddesk/desktop/global_hotkey_controller.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/desktop/tray_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/launcher/launcher_controller.dart';
import 'package:islanddesk/launcher/sqlite_launcher_repository.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/productivity/productivity_controller.dart';
import 'package:islanddesk/productivity/sqlite_productivity_repository.dart';
import 'package:islanddesk/settings/sqlite_settings_repository.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/shelf/sqlite_shelf_repository.dart';
import 'package:islanddesk/src/rust/api/clipboard.dart';
import 'package:islanddesk/src/rust/api/system.dart';
import 'package:islanddesk/src/rust/frb_generated.dart';
import 'package:islanddesk/system_controls/system_controls_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final coreStatus = getCoreStatus();
  final clipboardSecurity = initializeClipboardSecurity();

  final settingsRepository = await SqliteSettingsRepository.open();
  final shelfController = ShelfController(
    repository: await SqliteShelfRepository.open(),
  );
  await shelfController.load();
  final clipboardController = ClipboardController(
    enabled: clipboardSecurity.ready,
    repository:
        clipboardSecurity.ready ? await SqliteClipboardRepository.open() : null,
  );
  await clipboardController.start();
  final productivityController = ProductivityController(
    repository: clipboardSecurity.ready
        ? await SqliteProductivityRepository.open()
        : null,
  );
  await productivityController.start();
  final systemControlsController = SystemControlsController();
  await systemControlsController.start();
  final monitorService = MonitorService();
  final availableMonitors = await monitorService.listAvailableMonitors();
  final mediaController = MediaController();
  await mediaController.start();
  final launcherController = LauncherController(
    repository: await SqliteLauncherRepository.open(),
  );
  await launcherController.load();
  final fullscreenController = FullscreenController();
  await fullscreenController.start();
  final desktopWindow = DesktopWindowController(monitorService: monitorService);
  late final ApplicationController application;
  final globalHotkeyController = GlobalHotkeyController(
    onActivated: () {
      application.showIsland();
      unawaited(desktopWindow.show());
    },
  );
  application = ApplicationController(
    mediaController: mediaController,
    launcherController: launcherController,
    shelfController: shelfController,
    clipboardController: clipboardController,
    productivityController: productivityController,
    systemControlsController: systemControlsController,
    globalHotkeyController: globalHotkeyController,
    initialSettings: await settingsRepository.load(),
    settingsRepository: settingsRepository,
    availableMonitors: availableMonitors,
    coreStatusLabel: '${coreStatus.name} ${coreStatus.version} • '
        '${coreStatus.targetOs}/${coreStatus.targetArch}',
    clipboardSecurityReady: clipboardSecurity.ready,
    clipboardSecurityBackend: clipboardSecurity.backend,
  );
  final edgeRevealController = EdgeRevealController(
    monitorService: monitorService,
  );
  await edgeRevealController.start(
    monitorPreference: application.monitorPreference,
    fixedMonitorId: application.fixedMonitorId,
  );
  await desktopWindow.initialize(
    IslandState.collapsed,
    monitorPreference: application.monitorPreference,
    fixedMonitorId: application.fixedMonitorId,
    fullscreenSuppressed: application.shouldSuppressForFullscreen(
      fullscreenController.isForegroundFullscreen,
    ),
    autoHideSuppressed: application.isPanelAutoHidden,
  );
  await desktopWindow.setAlwaysOnTop(application.alwaysOnTop);
  await globalHotkeyController.start(application.globalHotkeyShortcut);

  void syncWindow() {
    switch (application.view) {
      case ApplicationView.island:
        desktopWindow.showState(application.island.state);
        break;
      case ApplicationView.settings:
        desktopWindow.showSettings();
        break;
    }
    unawaited(desktopWindow.setAlwaysOnTop(application.alwaysOnTop));
    desktopWindow.setMonitorPreference(
      application.monitorPreference,
      application.fixedMonitorId,
    );
    edgeRevealController.configure(
      application.monitorPreference,
      application.fixedMonitorId,
    );
    edgeRevealController.setEnabled(application.isPanelAutoHidden);
    unawaited(
      desktopWindow.setFullscreenSuppressed(
        application.shouldSuppressForFullscreen(
          fullscreenController.isForegroundFullscreen,
        ),
      ),
    );
    unawaited(
      desktopWindow.setAutoHideSuppressed(application.isPanelAutoHidden),
    );
  }

  void syncEdgeReveal() {
    if (edgeRevealController.isAtRevealEdge) {
      if (!application.shouldSuppressForFullscreen(
        fullscreenController.isForegroundFullscreen,
      )) {
        application.revealIslandFromEdge();
      }
    } else if (!application.isPanelAutoHidden) {
      application.panelPointerExited();
    }
  }

  application.addListener(syncWindow);
  fullscreenController.addListener(syncWindow);
  edgeRevealController.addListener(syncEdgeReveal);
  syncEdgeReveal();

  late final TrayController tray;
  tray = TrayController(
    onShowIsland: () {
      application.showIsland();
      unawaited(desktopWindow.show());
    },
    onShowSettings: () {
      application.showSettings();
      unawaited(desktopWindow.show());
    },
    onExit: () async {
      application.removeListener(syncWindow);
      fullscreenController.removeListener(syncWindow);
      edgeRevealController.removeListener(syncEdgeReveal);
      await tray.dispose();
      await application.close();
      application.dispose();
      fullscreenController.dispose();
      edgeRevealController.dispose();
      RustLib.dispose();
      await desktopWindow.destroy();
    },
  );
  await tray.initialize();

  runApp(IslandDeskApp(controller: application));
}
