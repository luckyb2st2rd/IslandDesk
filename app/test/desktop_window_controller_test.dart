import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/desktop_window_controller.dart';
import 'package:islanddesk/island/island_state.dart';

void main() {
  test('adds transparent margins to the native window size', () {
    expect(
      DesktopWindowController.windowSizeFor(IslandState.collapsed),
      const Size(244, 88),
    );
    expect(
      DesktopWindowController.windowSizeFor(IslandState.expanded),
      const Size(568, 364),
    );
  });
}
