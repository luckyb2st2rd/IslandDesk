import 'dart:async';

import 'package:flutter/foundation.dart';

class PanelVisibilityController extends ChangeNotifier {
  PanelVisibilityController({
    this.hideDelay = const Duration(milliseconds: 1500),
    bool initiallyHidden = true,
  }) : _isHidden = initiallyHidden;

  final Duration hideDelay;
  Timer? _hideTimer;
  bool _isHidden;

  bool get isHidden => _isHidden;

  void reveal() {
    _hideTimer?.cancel();
    if (!_isHidden) return;
    _isHidden = false;
    notifyListeners();
  }

  void pointerEntered() {
    _hideTimer?.cancel();
  }

  void pointerExited() {
    _hideTimer?.cancel();
    _hideTimer = Timer(hideDelay, hideNow);
  }

  void hideNow() {
    _hideTimer?.cancel();
    if (_isHidden) return;
    _isHidden = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}
