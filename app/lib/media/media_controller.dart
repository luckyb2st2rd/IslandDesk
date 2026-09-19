import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/src/rust/api/media.dart';

abstract interface class MediaGateway {
  bool get isSupported;

  Future<MediaSession?> currentSession();

  Future<bool> playPause();

  Future<bool> next();

  Future<bool> previous();
}

class RustMediaGateway implements MediaGateway {
  const RustMediaGateway();

  @override
  bool get isSupported => mediaPlatformSupported();

  @override
  Future<MediaSession?> currentSession() => getCurrentMediaSession();

  @override
  Future<bool> next() => mediaNext();

  @override
  Future<bool> playPause() => mediaPlayPause();

  @override
  Future<bool> previous() => mediaPrevious();
}

class MediaController extends ChangeNotifier {
  MediaController({
    MediaGateway? gateway,
    this.refreshInterval = const Duration(seconds: 1),
  }) : _gateway = gateway ?? const RustMediaGateway();

  final MediaGateway _gateway;
  final Duration refreshInterval;

  MediaSession? _session;
  Timer? _refreshTimer;
  bool _refreshInProgress = false;
  bool _started = false;
  String? _errorMessage;

  MediaSession? get session => _session;
  bool get isSupported => _gateway.isSupported;
  bool get isPlaying => _session?.playbackState == MediaPlaybackState.playing;
  String? get errorMessage => _errorMessage;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!isSupported) return;

    await refresh();
    _refreshTimer = Timer.periodic(
      refreshInterval,
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_refreshInProgress || !isSupported) return;
    _refreshInProgress = true;
    try {
      final nextSession = await _gateway.currentSession();
      if (_session != nextSession || _errorMessage != null) {
        _session = nextSession;
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

  Future<bool> playPause() => _execute(_gateway.playPause);

  Future<bool> next() => _execute(_gateway.next);

  Future<bool> previous() => _execute(_gateway.previous);

  Future<bool> _execute(Future<bool> Function() command) async {
    if (!isSupported) return false;
    try {
      final accepted = await command();
      await refresh();
      return accepted;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
