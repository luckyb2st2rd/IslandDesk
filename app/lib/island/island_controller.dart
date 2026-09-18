import 'package:flutter/foundation.dart';
import 'package:islanddesk/island/island_state.dart';

class IslandController extends ChangeNotifier {
  IslandController({IslandState initialState = IslandState.collapsed})
      : _state = initialState;

  IslandState _state;

  IslandState get state => _state;

  void pointerEntered() {
    if (_state == IslandState.collapsed) {
      _setState(IslandState.peek);
    }
  }

  void pointerExited() {
    if (_state == IslandState.peek) {
      _setState(IslandState.collapsed);
    }
  }

  void toggleExpanded() {
    _setState(
      _state == IslandState.expanded
          ? IslandState.collapsed
          : IslandState.expanded,
    );
  }

  void collapse() => _setState(IslandState.collapsed);

  void hide() => _setState(IslandState.hidden);

  void showTransientHud() => _setState(IslandState.transientHud);

  void _setState(IslandState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
