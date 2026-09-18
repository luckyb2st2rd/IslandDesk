import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:islanddesk/island/island_state.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowController {
  static const double _horizontalMargin = 24;
  static const double _topMargin = 10;
  static const double _bottomMargin = 34;

  IslandState? _requestedState;
  bool _isApplyingState = false;

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
    await _applyState(initialState);
    await windowManager.show();
  }

  void showState(IslandState state) {
    if (!_isSupportedDesktop) return;
    _requestedState = state;
    if (!_isApplyingState) {
      unawaited(_drainStateChanges());
    }
  }

  Future<void> _drainStateChanges() async {
    _isApplyingState = true;
    try {
      while (_requestedState != null) {
        final state = _requestedState!;
        _requestedState = null;
        await _applyState(state);
      }
    } finally {
      _isApplyingState = false;
    }
  }

  Future<void> _applyState(IslandState state) async {
    final size = windowSizeFor(state);
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

  static Size windowSizeFor(IslandState state) {
    final surfaceSize = state.surfaceSize;
    return Size(
      surfaceSize.width + (_horizontalMargin * 2),
      surfaceSize.height + _topMargin + _bottomMargin,
    );
  }
}
