import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/src/rust/api/fullscreen.dart' as rust_fullscreen;

abstract interface class FullscreenGateway {
  bool get isSupported;

  Future<bool> isForegroundFullscreen();
}

class RustFullscreenGateway implements FullscreenGateway {
  const RustFullscreenGateway();

  @override
  bool get isSupported => rust_fullscreen.fullscreenPlatformSupported();

  @override
  Future<bool> isForegroundFullscreen() =>
      rust_fullscreen.isForegroundFullscreen();
}

class FullscreenController extends ChangeNotifier {
  FullscreenController({
    FullscreenGateway? gateway,
    this.refreshInterval = const Duration(milliseconds: 500),
  }) : _gateway = gateway ?? const RustFullscreenGateway();

  final FullscreenGateway _gateway;
  final Duration refreshInterval;

  Timer? _timer;
  bool _started = false;
  bool _refreshInProgress = false;
  bool _isForegroundFullscreen = false;
  String? _errorMessage;

  bool get isSupported => _gateway.isSupported;
  bool get isForegroundFullscreen => _isForegroundFullscreen;
  String? get errorMessage => _errorMessage;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!isSupported) return;
    await refresh();
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (!isSupported || _refreshInProgress) return;
    _refreshInProgress = true;
    try {
      final next = await _gateway.isForegroundFullscreen();
      if (next != _isForegroundFullscreen || _errorMessage != null) {
        _isForegroundFullscreen = next;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (error) {
      final message = error.toString();
      if (_errorMessage != message) {
        _errorMessage = message;
        notifyListeners();
      }
    } finally {
      _refreshInProgress = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
