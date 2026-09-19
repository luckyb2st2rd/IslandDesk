import 'package:flutter/foundation.dart';
import 'package:islanddesk/island/island_state.dart';

enum IslandModule {
  media,
  shelf,
  clipboard,
  timer,
  notes,
  launcher,
  system,
}

class IslandController extends ChangeNotifier {
  IslandController({IslandState initialState = IslandState.collapsed})
      : _state = initialState;

  IslandState _state;
  IslandModule _selectedModule = IslandModule.media;

  IslandState get state => _state;
  IslandModule get selectedModule => _selectedModule;

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
      _state.showsDetails ? IslandState.collapsed : IslandState.expanded,
    );
  }

  void selectModule(IslandModule module) {
    final changed = _selectedModule != module;
    _selectedModule = module;
    if (!_state.showsDetails) {
      _state = IslandState.expanded;
      notifyListeners();
    } else if (changed) {
      notifyListeners();
    }
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
