import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/productivity/productivity_repository.dart';

class ProductivityController extends ChangeNotifier {
  ProductivityController({
    ProductivityRepository? repository,
    DateTime Function()? now,
    this.noteSaveDelay = const Duration(milliseconds: 350),
    this.tickInterval = const Duration(seconds: 1),
  })  : _repository = repository,
        _now = now ?? DateTime.now;

  final ProductivityRepository? _repository;
  final DateTime Function() _now;
  final Duration noteSaveDelay;
  final Duration tickInterval;

  String _noteText = '';
  int _timerDurationSeconds = 300;
  int _timerRemainingSeconds = 300;
  DateTime? _timerEndAt;
  bool _timerRunning = false;
  bool _started = false;
  bool _noteDirty = false;
  Timer? _noteSaveTimer;
  Timer? _ticker;
  Future<void> _pendingWrite = Future.value();

  String get noteText => _noteText;
  int get timerDurationSeconds => _timerDurationSeconds;
  int get timerRemainingSeconds => _timerRemainingSeconds;
  bool get timerRunning => _timerRunning;
  bool get notePersistenceEnabled => _repository != null;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final snapshot = await _repository?.load();
    if (snapshot != null) {
      _noteText = snapshot.noteText;
      _timerDurationSeconds = snapshot.timerDurationSeconds;
      _timerRemainingSeconds = snapshot.timerRemainingSeconds;
      _timerEndAt = snapshot.timerEndAt?.toUtc();
      _timerRunning = snapshot.timerRunning && _timerEndAt != null;
    }
    if (_timerRunning) {
      final expired = _refreshRemaining();
      if (expired) await _saveTimer();
    }
    if (_timerRunning) _startTicker();
    notifyListeners();
  }

  void updateNote(String text) {
    if (_noteText == text) return;
    _noteText = text;
    _noteDirty = true;
    _noteSaveTimer?.cancel();
    _noteSaveTimer = Timer(noteSaveDelay, () => unawaited(_flushNote()));
    notifyListeners();
  }

  Future<void> selectTimerDuration(int seconds) async {
    if (seconds <= 0) return;
    _ticker?.cancel();
    _timerDurationSeconds = seconds;
    _timerRemainingSeconds = seconds;
    _timerEndAt = null;
    _timerRunning = false;
    notifyListeners();
    await _saveTimer();
  }

  Future<void> toggleTimer() async {
    if (_timerRunning) {
      _refreshRemaining();
      _timerRunning = false;
      _timerEndAt = null;
      _ticker?.cancel();
    } else {
      if (_timerRemainingSeconds <= 0) {
        _timerRemainingSeconds = _timerDurationSeconds;
      }
      _timerEndAt = _now().toUtc().add(
            Duration(seconds: _timerRemainingSeconds),
          );
      _timerRunning = true;
      _startTicker();
    }
    notifyListeners();
    await _saveTimer();
  }

  Future<void> resetTimer() async {
    _ticker?.cancel();
    _timerRemainingSeconds = _timerDurationSeconds;
    _timerEndAt = null;
    _timerRunning = false;
    notifyListeners();
    await _saveTimer();
  }

  Future<void> refreshTimer() async {
    if (!_timerRunning) return;
    final expired = _refreshRemaining();
    notifyListeners();
    if (expired) await _saveTimer();
  }

  bool _refreshRemaining() {
    final endAt = _timerEndAt;
    if (!_timerRunning || endAt == null) return false;
    final milliseconds = endAt.difference(_now().toUtc()).inMilliseconds;
    if (milliseconds <= 0) {
      _timerRemainingSeconds = 0;
      _timerRunning = false;
      _timerEndAt = null;
      _ticker?.cancel();
      return true;
    }
    _timerRemainingSeconds = (milliseconds + 999) ~/ 1000;
    return false;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => unawaited(refreshTimer()));
  }

  Future<void> _flushNote() async {
    _noteSaveTimer?.cancel();
    if (!_noteDirty) return;
    _noteDirty = false;
    final text = _noteText;
    _pendingWrite = _pendingWrite.then((_) async {
      await _repository?.saveNote(text);
    });
    await _pendingWrite;
  }

  Future<void> _saveTimer() async {
    final duration = _timerDurationSeconds;
    final remaining = _timerRemainingSeconds;
    final endAt = _timerEndAt;
    final running = _timerRunning;
    _pendingWrite = _pendingWrite.then((_) async {
      await _repository?.saveTimer(
        durationSeconds: duration,
        remainingSeconds: remaining,
        endAt: endAt,
        running: running,
      );
    });
    await _pendingWrite;
  }

  Future<void> close() async {
    _ticker?.cancel();
    await _flushNote();
    await _pendingWrite;
    await _repository?.close();
  }

  @override
  void dispose() {
    _noteSaveTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
