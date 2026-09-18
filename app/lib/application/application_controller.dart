import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/settings_repository.dart';

enum ApplicationView { island, settings }

class ApplicationController extends ChangeNotifier {
  ApplicationController({
    IslandController? islandController,
    AppSettings initialSettings = const AppSettings(),
    SettingsRepository? settingsRepository,
  })  : island = islandController ?? IslandController(),
        _settings = initialSettings,
        _settingsRepository = settingsRepository {
    island.addListener(_forwardIslandChange);
  }

  final IslandController island;

  ApplicationView _view = ApplicationView.island;
  AppSettings _settings;
  final SettingsRepository? _settingsRepository;
  Future<void> _pendingSave = Future.value();

  ApplicationView get view => _view;
  bool get alwaysOnTop => _settings.alwaysOnTop;
  bool get animationsEnabled => _settings.animationsEnabled;

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
    super.dispose();
  }
}
