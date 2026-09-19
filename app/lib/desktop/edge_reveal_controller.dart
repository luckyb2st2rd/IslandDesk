import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:screen_retriever/screen_retriever.dart';

class EdgeRevealController extends ChangeNotifier {
  EdgeRevealController({
    required MonitorService monitorService,
    this.pollInterval = const Duration(milliseconds: 120),
  }) : _monitorService = monitorService;

  static const double activationWidth = 220;
  static const double activationDepth = 4;

  final MonitorService _monitorService;
  final Duration pollInterval;

  MonitorPreference _monitorPreference = MonitorPreference.primary;
  String? _fixedMonitorId;
  Timer? _timer;
  bool _refreshInProgress = false;
  bool _isAtRevealEdge = false;
  bool _enabled = true;

  bool get isAtRevealEdge => _isAtRevealEdge;

  Future<void> start({
    required MonitorPreference monitorPreference,
    String? fixedMonitorId,
  }) async {
    _monitorPreference = monitorPreference;
    _fixedMonitorId = fixedMonitorId;
    await refresh();
    _timer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  void configure(MonitorPreference preference, String? fixedMonitorId) {
    _monitorPreference = preference;
    _fixedMonitorId = fixedMonitorId;
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value && _isAtRevealEdge) {
      _isAtRevealEdge = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!_enabled || _refreshInProgress) return;
    _refreshInProgress = true;
    try {
      final monitor = await _monitorService.resolve(
        mode: _monitorPreference,
        fixedMonitorId: _fixedMonitorId,
      );
      final next = monitor != null &&
          isInsideRevealZone(
            await _monitorService.getCursorPosition(),
            monitor.display,
          );
      if (next != _isAtRevealEdge) {
        _isAtRevealEdge = next;
        notifyListeners();
      }
    } catch (_) {
      if (_isAtRevealEdge) {
        _isAtRevealEdge = false;
        notifyListeners();
      }
    } finally {
      _refreshInProgress = false;
    }
  }

  @visibleForTesting
  static bool isInsideRevealZone(Offset cursor, Display display) {
    final origin = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    final centerX = origin.dx + (size.width / 2);
    return cursor.dx >= centerX - (activationWidth / 2) &&
        cursor.dx <= centerX + (activationWidth / 2) &&
        cursor.dy >= origin.dy &&
        cursor.dy <= origin.dy + activationDepth;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
