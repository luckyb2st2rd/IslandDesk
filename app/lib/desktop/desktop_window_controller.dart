import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/desktop/window_visibility_policy.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowController with WindowListener, ScreenListener {
  DesktopWindowController({MonitorService? monitorService})
      : _monitorService = monitorService ?? MonitorService();

  static const double _horizontalMargin = 24;
  static const double _topMargin = 10;
  static const double _bottomMargin = 34;

  static const Size settingsWindowSize = Size(680, 560);

  Size? _requestedSize;
  Size? _currentSize;
  bool _isApplyingSize = false;
  final MonitorService _monitorService;
  MonitorPreference _monitorPreference = MonitorPreference.primary;
  String? _fixedMonitorId;
  String? _currentDisplayId;
  Timer? _followActiveTimer;
  bool _isCheckingActiveMonitor = false;
  final WindowVisibilityPolicy _visibilityPolicy = WindowVisibilityPolicy();

  bool get _isSupportedDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> initialize(
    IslandState initialState, {
    MonitorPreference monitorPreference = MonitorPreference.primary,
    String? fixedMonitorId,
    bool fullscreenSuppressed = false,
    bool autoHideSuppressed = false,
  }) async {
    if (!_isSupportedDesktop) return;

    _monitorPreference = monitorPreference;
    _fixedMonitorId = fixedMonitorId;
    _visibilityPolicy.setFullscreenSuppressed(fullscreenSuppressed);
    _visibilityPolicy.setAutoHideSuppressed(autoHideSuppressed);

    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: windowSizeFor(initialState),
        backgroundColor: const Color(0x00000000),
        skipTaskbar: true,
        title: 'IslandDesk',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        alwaysOnTop: true,
      ),
    );

    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    screenRetriever.addListener(this);
    _configureMonitorTracking();
    await _applySize(windowSizeFor(initialState));
    if (_visibilityPolicy.shouldBeVisible) {
      await windowManager.show();
    }
  }

  void showState(IslandState state) {
    if (!_isSupportedDesktop) return;
    _queueSize(windowSizeFor(state));
  }

  void showSettings() {
    if (!_isSupportedDesktop) return;
    _queueSize(settingsWindowSize);
  }

  void setMonitorPreference(
    MonitorPreference preference,
    String? fixedMonitorId,
  ) {
    if (!_isSupportedDesktop ||
        (_monitorPreference == preference &&
            _fixedMonitorId == fixedMonitorId)) {
      return;
    }
    _monitorPreference = preference;
    _fixedMonitorId = fixedMonitorId;
    _configureMonitorTracking();
    final size = _currentSize;
    if (size != null) _queueSize(size);
  }

  void _queueSize(Size size) {
    _requestedSize = size;
    if (!_isApplyingSize) {
      unawaited(_drainSizeChanges());
    }
  }

  Future<void> _drainSizeChanges() async {
    _isApplyingSize = true;
    try {
      while (_requestedSize != null) {
        final size = _requestedSize!;
        _requestedSize = null;
        await _applySize(size);
      }
    } finally {
      _isApplyingSize = false;
    }
  }

  Future<void> _applySize(Size size) async {
    _currentSize = size;
    final monitor = await _monitorService.resolve(
      mode: _monitorPreference,
      fixedMonitorId: _fixedMonitorId,
    );
    await windowManager.setSize(size);
    if (monitor != null) {
      _currentDisplayId = monitor.display.id;
      await windowManager.setPosition(
        MonitorService.topCenterPosition(monitor.display, size),
      );
    }
  }

  void _configureMonitorTracking() {
    _followActiveTimer?.cancel();
    _followActiveTimer = null;
    if (_monitorPreference == MonitorPreference.followActive) {
      _followActiveTimer = Timer.periodic(
        const Duration(milliseconds: 400),
        (_) => unawaited(_moveToActiveMonitorIfNeeded()),
      );
    }
  }

  Future<void> _moveToActiveMonitorIfNeeded() async {
    if (_isCheckingActiveMonitor) return;
    _isCheckingActiveMonitor = true;
    try {
      final monitor = await _monitorService.resolve(
        mode: _monitorPreference,
        fixedMonitorId: _fixedMonitorId,
      );
      final size = _currentSize;
      if (monitor == null ||
          size == null ||
          monitor.display.id == _currentDisplayId) {
        return;
      }
      _queueSize(size);
    } finally {
      _isCheckingActiveMonitor = false;
    }
  }

  Future<void> show() async {
    if (!_isSupportedDesktop) return;
    _visibilityPolicy.requestShow();
    if (!_visibilityPolicy.shouldBeVisible) return;
    final size = _currentSize;
    if (size != null) await _applySize(size);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hide() async {
    if (!_isSupportedDesktop) return;
    _visibilityPolicy.requestHide();
    await windowManager.hide();
  }

  Future<void> setFullscreenSuppressed(bool value) async {
    if (!_isSupportedDesktop ||
        _visibilityPolicy.fullscreenSuppressed == value) {
      return;
    }
    final wasVisible = _visibilityPolicy.shouldBeVisible;
    _visibilityPolicy.setFullscreenSuppressed(value);
    await _applyVisibilityChange(wasVisible);
  }

  Future<void> setAutoHideSuppressed(bool value) async {
    if (!_isSupportedDesktop || _visibilityPolicy.autoHideSuppressed == value) {
      return;
    }
    final wasVisible = _visibilityPolicy.shouldBeVisible;
    _visibilityPolicy.setAutoHideSuppressed(value);
    await _applyVisibilityChange(wasVisible);
  }

  Future<void> _applyVisibilityChange(bool wasVisible) async {
    final shouldBeVisible = _visibilityPolicy.shouldBeVisible;
    if (wasVisible == shouldBeVisible) return;
    if (!shouldBeVisible) {
      await windowManager.hide();
      return;
    }
    final size = _currentSize;
    if (size != null) await _applySize(size);
    await windowManager.show();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    if (!_isSupportedDesktop) return;
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> destroy() async {
    if (!_isSupportedDesktop) return;
    _followActiveTimer?.cancel();
    screenRetriever.removeListener(this);
    windowManager.removeListener(this);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    unawaited(hide());
  }

  @override
  void onScreenEvent(String eventName) {
    final size = _currentSize;
    if (size != null) _queueSize(size);
  }

  static Size windowSizeFor(IslandState state) {
    final surfaceSize = state.surfaceSize;
    return Size(
      surfaceSize.width + (_horizontalMargin * 2),
      surfaceSize.height + _topMargin + _bottomMargin,
    );
  }
}
