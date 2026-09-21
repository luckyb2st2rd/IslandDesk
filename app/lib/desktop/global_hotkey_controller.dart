import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/src/rust/api/hotkey.dart' as rust_hotkey;

abstract interface class GlobalHotkeyGateway {
  bool get isSupported;

  void configure(GlobalHotkeyShortcut shortcut);

  Stream<rust_hotkey.GlobalHotkeyEvent> watch();
}

class RustGlobalHotkeyGateway implements GlobalHotkeyGateway {
  const RustGlobalHotkeyGateway();

  @override
  bool get isSupported => Platform.isWindows;

  @override
  void configure(GlobalHotkeyShortcut shortcut) =>
      rust_hotkey.configureGlobalHotkey(shortcut: shortcut.storageValue);

  @override
  Stream<rust_hotkey.GlobalHotkeyEvent> watch() =>
      rust_hotkey.watchGlobalHotkey();
}

class GlobalHotkeyController extends ChangeNotifier {
  GlobalHotkeyController({
    required VoidCallback onActivated,
    GlobalHotkeyGateway? gateway,
  })  : _onActivated = onActivated,
        _gateway = gateway ?? const RustGlobalHotkeyGateway();

  final VoidCallback _onActivated;
  final GlobalHotkeyGateway _gateway;
  StreamSubscription<rust_hotkey.GlobalHotkeyEvent>? _subscription;
  GlobalHotkeyShortcut _shortcut = GlobalHotkeyShortcut.ctrlAltSpace;
  bool _registered = false;
  String? _errorCode;

  bool get isSupported => _gateway.isSupported;
  bool get registered => _registered;
  String? get errorCode => _errorCode;
  GlobalHotkeyShortcut get shortcut => _shortcut;

  Future<void> start(GlobalHotkeyShortcut shortcut) async {
    _shortcut = shortcut;
    if (!isSupported) return;
    try {
      _gateway.configure(shortcut);
      _subscription = _gateway.watch().listen(
            _accept,
            onError: (Object _) => _setFailure('listener_failed'),
          );
    } catch (_) {
      _setFailure('listener_failed');
    }
  }

  void configure(GlobalHotkeyShortcut shortcut) {
    if (_shortcut == shortcut) return;
    _shortcut = shortcut;
    if (!isSupported) {
      notifyListeners();
      return;
    }
    try {
      _gateway.configure(shortcut);
    } catch (_) {
      _setFailure('configuration_failed');
    }
  }

  void _accept(rust_hotkey.GlobalHotkeyEvent event) {
    final changed =
        _registered != event.registered || _errorCode != event.errorCode;
    _registered = event.registered;
    _errorCode = event.errorCode;
    if (changed) notifyListeners();
    if (event.activated) _onActivated();
  }

  void _setFailure(String errorCode) {
    _registered = false;
    _errorCode = errorCode;
    notifyListeners();
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
