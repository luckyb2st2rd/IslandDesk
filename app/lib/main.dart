import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/desktop/desktop_window_controller.dart';
import 'package:islanddesk/desktop/tray_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/settings/sqlite_settings_repository.dart';
import 'package:islanddesk/src/rust/api/system.dart';
import 'package:islanddesk/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final coreStatus = getCoreStatus();

  final settingsRepository = await SqliteSettingsRepository.open();
  final application = ApplicationController(
    initialSettings: await settingsRepository.load(),
    settingsRepository: settingsRepository,
    coreStatusLabel: '${coreStatus.name} ${coreStatus.version} • '
        '${coreStatus.targetOs}/${coreStatus.targetArch}',
  );
  final desktopWindow = DesktopWindowController();
  await desktopWindow.initialize(IslandState.collapsed);
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
  }

  application.addListener(syncWindow);

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
      await tray.dispose();
      await application.close();
      application.dispose();
      RustLib.dispose();
      await desktopWindow.destroy();
    },
  );
  await tray.initialize();

  runApp(IslandDeskApp(controller: application));
}
