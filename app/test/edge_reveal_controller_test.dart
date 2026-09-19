import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/edge_reveal_controller.dart';
import 'package:screen_retriever/screen_retriever.dart';

void main() {
  const display = Display(
    id: 'primary',
    size: Size(1920, 1080),
    visiblePosition: Offset.zero,
    visibleSize: Size(1920, 1040),
    scaleFactor: 1,
  );

  test('uses only a narrow top-center reveal zone', () {
    expect(
      EdgeRevealController.isInsideRevealZone(const Offset(960, 0), display),
      isTrue,
    );
    expect(
      EdgeRevealController.isInsideRevealZone(const Offset(960, 5), display),
      isFalse,
    );
    expect(
      EdgeRevealController.isInsideRevealZone(const Offset(100, 0), display),
      isFalse,
    );
  });
}
