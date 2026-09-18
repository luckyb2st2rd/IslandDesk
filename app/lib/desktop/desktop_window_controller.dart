import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:islanddesk/island/island_state.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowController with WindowListener {
  static const double _horizontalMargin = 24;
  static const double _topMargin = 10;
  static const double _bottomMargin = 34;

  static const Size settingsWindowSize = Size(680, 560);

  Size? _requestedSize;
  bool _isApplyingSize = false;

  bool get _isSupportedDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> initialize(IslandState initialState) async {
    if (!_isSupportedDesktop) return;

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
    await _applySize(windowSizeFor(initialState));
    await windowManager.show();
  }

  void showState(IslandState state) {
    if (!_isSupportedDesktop) return;
    _queueSize(windowSizeFor(state));
  }

  void showSettings() {
    if (!_isSupportedDesktop) return;
    _queueSize(settingsWindowSize);
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
    final display = await screenRetriever.getPrimaryDisplay();
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    final position = Offset(
      visiblePosition.dx + (visibleSize.width - size.width) / 2,
      visiblePosition.dy,
    );

    await windowManager.setSize(size);
    await windowManager.setPosition(position);
  }

  Future<void> show() async {
    if (!_isSupportedDesktop) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hide() async {
    if (!_isSupportedDesktop) return;
    await windowManager.hide();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    if (!_isSupportedDesktop) return;
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> destroy() async {
    if (!_isSupportedDesktop) return;
    windowManager.removeListener(this);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    unawaited(hide());
  }

  static Size windowSizeFor(IslandState state) {
    final surfaceSize = state.surfaceSize;
    return Size(
      surfaceSize.width + (_horizontalMargin * 2),
      surfaceSize.height + _topMargin + _bottomMargin,
    );
  }
}
