import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/clipboard/clipboard_controller.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/desktop/panel_visibility_controller.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/productivity/productivity_controller.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/settings_repository.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/system_controls/system_controls_controller.dart';

enum ApplicationView { island, settings }

class ApplicationController extends ChangeNotifier {
  ApplicationController({
    IslandController? islandController,
    MediaController? mediaController,
    ShelfController? shelfController,
    ClipboardController? clipboardController,
    ProductivityController? productivityController,
    SystemControlsController? systemControlsController,
    PanelVisibilityController? panelVisibilityController,
    AppSettings initialSettings = const AppSettings(),
    SettingsRepository? settingsRepository,
    this.availableMonitors = const [],
    this.coreStatusLabel = 'Rust core preview',
    this.clipboardSecurityReady = false,
    this.clipboardSecurityBackend = 'unavailable',
  })  : island = islandController ?? IslandController(),
        media = mediaController ?? MediaController(),
        shelf = shelfController ?? ShelfController(),
        clipboard = clipboardController ??
            ClipboardController(enabled: clipboardSecurityReady),
        productivity = productivityController ?? ProductivityController(),
        systemControls = systemControlsController ?? SystemControlsController(),
        panelVisibility =
            panelVisibilityController ?? PanelVisibilityController(),
        _settings = initialSettings,
        _settingsRepository = settingsRepository {
    if (_settings.monitorPreference == MonitorPreference.fixed &&
        _settings.fixedMonitorId == null &&
        availableMonitors.isNotEmpty) {
      _settings =
          _settings.copyWith(fixedMonitorId: availableMonitors.first.id);
    }
    island.addListener(_forwardIslandChange);
    panelVisibility.addListener(_forwardPanelVisibilityChange);
  }

  final IslandController island;
  final MediaController media;
  final ShelfController shelf;
  final ClipboardController clipboard;
  final ProductivityController productivity;
  final SystemControlsController systemControls;
  final PanelVisibilityController panelVisibility;
  final String coreStatusLabel;
  final bool clipboardSecurityReady;
  final String clipboardSecurityBackend;
  final List<MonitorOption> availableMonitors;

  ApplicationView _view = ApplicationView.island;
  AppSettings _settings;
  final SettingsRepository? _settingsRepository;
  Future<void> _pendingSave = Future.value();

  ApplicationView get view => _view;
  bool get alwaysOnTop => _settings.alwaysOnTop;
  bool get animationsEnabled => _settings.animationsEnabled;
  bool get hideInFullscreen => _settings.hideInFullscreen;
  bool get autoHidePanel => _settings.autoHidePanel;
  MonitorPreference get monitorPreference => _settings.monitorPreference;
  String? get fixedMonitorId => _settings.fixedMonitorId;
  bool get isPanelAutoHidden =>
      _settings.autoHidePanel &&
      _view == ApplicationView.island &&
      panelVisibility.isHidden;

  void showIsland() {
    panelVisibility.reveal();
    if (_view == ApplicationView.island &&
        island.state == IslandState.collapsed) {
      return;
    }
    _view = ApplicationView.island;
    if (island.state == IslandState.collapsed) {
      notifyListeners();
    } else {
      island.collapse();
    }
  }

  void revealIslandFromEdge() {
    if (_view != ApplicationView.island) return;
    panelVisibility.reveal();
  }

  void panelPointerEntered() => panelVisibility.pointerEntered();

  void panelPointerExited() {
    if (_settings.autoHidePanel) panelVisibility.pointerExited();
  }

  void showSettings() {
    if (_view == ApplicationView.settings) return;
    _view = ApplicationView.settings;
    notifyListeners();
  }

  void setAlwaysOnTop(bool value) {
    if (_settings.alwaysOnTop == value) return;
    _settings = _settings.copyWith(alwaysOnTop: value);
    notifyListeners();
    _scheduleSave();
  }

  void setAnimationsEnabled(bool value) {
    if (_settings.animationsEnabled == value) return;
    _settings = _settings.copyWith(animationsEnabled: value);
    notifyListeners();
    _scheduleSave();
  }

  void setHideInFullscreen(bool value) {
    if (_settings.hideInFullscreen == value) return;
    _settings = _settings.copyWith(hideInFullscreen: value);
    notifyListeners();
    _scheduleSave();
  }

  void setAutoHidePanel(bool value) {
    if (_settings.autoHidePanel == value) return;
    _settings = _settings.copyWith(autoHidePanel: value);
    if (!value) panelVisibility.reveal();
    notifyListeners();
    _scheduleSave();
  }

  bool shouldSuppressForFullscreen(bool isForegroundFullscreen) =>
      _settings.hideInFullscreen &&
      isForegroundFullscreen &&
      _view == ApplicationView.island;

  void setMonitorPreference(MonitorPreference value) {
    if (_settings.monitorPreference == value) return;
    final fixedMonitorId = value == MonitorPreference.fixed &&
            _settings.fixedMonitorId == null &&
            availableMonitors.isNotEmpty
        ? availableMonitors.first.id
        : _settings.fixedMonitorId;
    _settings = _settings.copyWith(
      monitorPreference: value,
      fixedMonitorId: fixedMonitorId,
    );
    notifyListeners();
    _scheduleSave();
  }

  void setFixedMonitor(String monitorId) {
    if (_settings.fixedMonitorId == monitorId) return;
    _settings = _settings.copyWith(fixedMonitorId: monitorId);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    final repository = _settingsRepository;
    if (repository == null) return;
    final snapshot = _settings;
    _pendingSave = _pendingSave.then((_) => repository.save(snapshot));
  }

  Future<void> close() async {
    await _pendingSave;
    await shelf.close();
    await clipboard.close();
    await productivity.close();
    await systemControls.close();
    await _settingsRepository?.close();
  }

  void _forwardIslandChange() => notifyListeners();

  void _forwardPanelVisibilityChange() {
    if (panelVisibility.isHidden && island.state != IslandState.collapsed) {
      island.collapse();
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    island.removeListener(_forwardIslandChange);
    panelVisibility.removeListener(_forwardPanelVisibilityChange);
    island.dispose();
    media.dispose();
    shelf.dispose();
    clipboard.dispose();
    productivity.dispose();
    systemControls.dispose();
    panelVisibility.dispose();
    super.dispose();
  }
}
