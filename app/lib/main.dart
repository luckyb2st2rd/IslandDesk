import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/desktop/desktop_window_controller.dart';
import 'package:islanddesk/desktop/edge_reveal_controller.dart';
import 'package:islanddesk/desktop/fullscreen_controller.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/desktop/tray_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/settings/sqlite_settings_repository.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/shelf/sqlite_shelf_repository.dart';
import 'package:islanddesk/src/rust/api/system.dart';
import 'package:islanddesk/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final coreStatus = getCoreStatus();

  final settingsRepository = await SqliteSettingsRepository.open();
  final shelfController = ShelfController(
    repository: await SqliteShelfRepository.open(),
  );
  await shelfController.load();
  final monitorService = MonitorService();
  final availableMonitors = await monitorService.listAvailableMonitors();
  final mediaController = MediaController();
  await mediaController.start();
  final fullscreenController = FullscreenController();
  await fullscreenController.start();
  final application = ApplicationController(
    mediaController: mediaController,
    shelfController: shelfController,
    initialSettings: await settingsRepository.load(),
    settingsRepository: settingsRepository,
    availableMonitors: availableMonitors,
    coreStatusLabel: '${coreStatus.name} ${coreStatus.version} • '
        '${coreStatus.targetOs}/${coreStatus.targetArch}',
  );
  final edgeRevealController = EdgeRevealController(
    monitorService: monitorService,
  );
  await edgeRevealController.start(
    monitorPreference: application.monitorPreference,
    fixedMonitorId: application.fixedMonitorId,
  );
  final desktopWindow = DesktopWindowController(monitorService: monitorService);
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
