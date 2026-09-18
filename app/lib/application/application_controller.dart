import 'package:flutter/foundation.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';

enum ApplicationView { island, settings }

class ApplicationController extends ChangeNotifier {
  ApplicationController({IslandController? islandController})
      : island = islandController ?? IslandController() {
    island.addListener(_forwardIslandChange);
  }

  final IslandController island;

  ApplicationView _view = ApplicationView.island;
  bool _alwaysOnTop = true;
  bool _animationsEnabled = true;

  ApplicationView get view => _view;
  bool get alwaysOnTop => _alwaysOnTop;
  bool get animationsEnabled => _animationsEnabled;

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
    if (_alwaysOnTop == value) return;
    _alwaysOnTop = value;
    notifyListeners();
  }

  void setAnimationsEnabled(bool value) {
    if (_animationsEnabled == value) return;
    _animationsEnabled = value;
    notifyListeners();
  }

  void _forwardIslandChange() => notifyListeners();

  @override
  void dispose() {
    island.removeListener(_forwardIslandChange);
    island.dispose();
    super.dispose();
  }
}
