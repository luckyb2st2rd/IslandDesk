import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/desktop/desktop_window_controller.dart';
import 'package:islanddesk/desktop/fullscreen_controller.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/desktop/tray_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/settings/sqlite_settings_repository.dart';
import 'package:islanddesk/src/rust/api/system.dart';
import 'package:islanddesk/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final coreStatus = getCoreStatus();

  final settingsRepository = await SqliteSettingsRepository.open();
  final monitorService = MonitorService();
  final availableMonitors = await monitorService.listAvailableMonitors();
  final mediaController = MediaController();
  await mediaController.start();
  final fullscreenController = FullscreenController();
  await fullscreenController.start();
  final application = ApplicationController(
    mediaController: mediaController,
    initialSettings: await settingsRepository.load(),
    settingsRepository: settingsRepository,
    availableMonitors: availableMonitors,
    coreStatusLabel: '${coreStatus.name} ${coreStatus.version} • '
        '${coreStatus.targetOs}/${coreStatus.targetArch}',
  );
  final desktopWindow = DesktopWindowController(monitorService: monitorService);
  await desktopWindow.initialize(
    IslandState.collapsed,
    monitorPreference: application.monitorPreference,
    fixedMonitorId: application.fixedMonitorId,
    fullscreenSuppressed: application.shouldSuppressForFullscreen(
      fullscreenController.isForegroundFullscreen,
    ),
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
    unawaited(
      desktopWindow.setFullscreenSuppressed(
        application.shouldSuppressForFullscreen(
          fullscreenController.isForegroundFullscreen,
        ),
      ),
    );
  }

  application.addListener(syncWindow);
  fullscreenController.addListener(syncWindow);

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
      await tray.dispose();
      await application.close();
      application.dispose();
      fullscreenController.dispose();
      RustLib.dispose();
      await desktopWindow.destroy();
    },
  );
  await tray.initialize();

  runApp(IslandDeskApp(controller: application));
}
