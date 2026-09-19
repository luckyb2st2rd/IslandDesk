import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/src/rust/api/media.dart';

abstract interface class MediaGateway {
  bool get isSupported;

  Future<MediaSession?> currentSession();

  Future<bool> playPause();

  Future<bool> next();

  Future<bool> previous();

  Future<bool> seek(int positionMs);

  Stream<MediaSession?> watchSessions();
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

  @override
  Future<bool> seek(int positionMs) =>
      mediaSeek(positionMs: BigInt.from(positionMs));

  @override
  Stream<MediaSession?> watchSessions() => watchMediaSessions();
}

class MediaController extends ChangeNotifier {
  MediaController({
    MediaGateway? gateway,
    this.refreshInterval = const Duration(seconds: 1),
  }) : _gateway = gateway ?? const RustMediaGateway();

  final MediaGateway _gateway;
  final Duration refreshInterval;

  MediaSession? _session;
  StreamSubscription<MediaSession?>? _sessionSubscription;
  Timer? _progressTimer;
  bool _refreshInProgress = false;
  bool _started = false;
  String? _errorMessage;
  DateTime? _lastSessionUpdate;
  int? _pendingPositionMs;

  MediaSession? get session => _session;
  bool get isSupported => _gateway.isSupported;
  bool get isPlaying => _session?.playbackState == MediaPlaybackState.playing;
  String? get errorMessage => _errorMessage;
  int get displayPositionMs {
    final session = _session;
    if (session == null) return 0;
    if (_pendingPositionMs case final pending?) return pending;
    var position = session.positionMs.toInt();
    if (isPlaying && _lastSessionUpdate != null) {
      position += DateTime.now().difference(_lastSessionUpdate!).inMilliseconds;
    }
    return position.clamp(0, session.durationMs.toInt());
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!isSupported) return;

    await refresh();
    _sessionSubscription = _gateway.watchSessions().listen(
          _acceptSession,
          onError: _acceptError,
        );
    _progressTimer = Timer.periodic(
      refreshInterval,
      (_) {
        if (isPlaying &&
            displayPositionMs < (_session?.durationMs.toInt() ?? 0)) {
          notifyListeners();
        }
      },
    );
  }

  Future<void> refresh() async {
    if (_refreshInProgress || !isSupported) return;
    _refreshInProgress = true;
    try {
      final nextSession = await _gateway.currentSession();
      _acceptSession(nextSession);
    } catch (error) {
      _acceptError(error);
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<bool> playPause() => _execute(_gateway.playPause);

  Future<bool> next() => _execute(_gateway.next);

  Future<bool> previous() => _execute(_gateway.previous);

  Future<bool> seek(int positionMs) =>
      _execute(() => _gateway.seek(positionMs));

  void previewSeek(int positionMs) {
    final duration = _session?.durationMs.toInt() ?? 0;
    _pendingPositionMs = positionMs.clamp(0, duration);
    notifyListeners();
  }

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

  void _acceptSession(MediaSession? nextSession) {
    final changed = !_sessionsEqual(_session, nextSession);
    if (changed) {
      _session = nextSession;
      _pendingPositionMs = null;
      _lastSessionUpdate = DateTime.now();
    }
    if (changed || _errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _acceptError(Object error) {
    final message = error.toString();
    final clearedPendingPosition = _pendingPositionMs != null;
    _pendingPositionMs = null;
    if (_errorMessage != message || clearedPendingPosition) {
      _errorMessage = message;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    _progressTimer?.cancel();
    super.dispose();
  }
}

bool _sessionsEqual(MediaSession? left, MediaSession? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;
  return left.sourceAppId == right.sourceAppId &&
      left.sourceAppName == right.sourceAppName &&
      left.title == right.title &&
      left.artist == right.artist &&
      left.albumTitle == right.albumTitle &&
      left.playbackState == right.playbackState &&
      left.positionMs == right.positionMs &&
      left.durationMs == right.durationMs &&
      listEquals(left.artwork, right.artwork) &&
      left.artworkContentType == right.artworkContentType &&
      left.capabilities == right.capabilities;
}
