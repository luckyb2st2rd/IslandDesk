import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayController with TrayListener {
  TrayController({
    required this.onShowIsland,
    required this.onShowSettings,
    required this.onExit,
  });

  static const _trayIconPath = 'windows/runner/resources/app_icon.ico';

  final VoidCallback onShowIsland;
  final VoidCallback onShowSettings;
  final Future<void> Function() onExit;

  bool _isExiting = false;

  Future<void> initialize() async {
    trayManager.addListener(this);
    await trayManager.setIcon(_trayIconPath);
    await trayManager.setToolTip('IslandDesk');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show IslandDesk'),
          MenuItem(key: 'settings', label: 'Settings'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Exit'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => onShowIsland();

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        onShowIsland();
        break;
      case 'settings':
        onShowSettings();
        break;
      case 'exit':
        if (!_isExiting) {
          _isExiting = true;
          unawaited(onExit());
        }
        break;
    }
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
