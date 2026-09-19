import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/settings_repository.dart';

enum ApplicationView { island, settings }

class ApplicationController extends ChangeNotifier {
  ApplicationController({
    IslandController? islandController,
    MediaController? mediaController,
    AppSettings initialSettings = const AppSettings(),
    SettingsRepository? settingsRepository,
    this.availableMonitors = const [],
    this.coreStatusLabel = 'Rust core preview',
  })  : island = islandController ?? IslandController(),
        media = mediaController ?? MediaController(),
        _settings = initialSettings,
        _settingsRepository = settingsRepository {
    if (_settings.monitorPreference == MonitorPreference.fixed &&
        _settings.fixedMonitorId == null &&
        availableMonitors.isNotEmpty) {
      _settings =
          _settings.copyWith(fixedMonitorId: availableMonitors.first.id);
    }
    island.addListener(_forwardIslandChange);
  }

  final IslandController island;
  final MediaController media;
  final String coreStatusLabel;
  final List<MonitorOption> availableMonitors;

  ApplicationView _view = ApplicationView.island;
  AppSettings _settings;
  final SettingsRepository? _settingsRepository;
  Future<void> _pendingSave = Future.value();

  ApplicationView get view => _view;
  bool get alwaysOnTop => _settings.alwaysOnTop;
  bool get animationsEnabled => _settings.animationsEnabled;
  MonitorPreference get monitorPreference => _settings.monitorPreference;
  String? get fixedMonitorId => _settings.fixedMonitorId;

  void showIsland() {
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
    await _settingsRepository?.close();
  }

  void _forwardIslandChange() => notifyListeners();

  @override
  void dispose() {
    island.removeListener(_forwardIslandChange);
    island.dispose();
    media.dispose();
    super.dispose();
  }
}
