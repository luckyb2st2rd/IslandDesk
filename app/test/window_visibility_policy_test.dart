import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/window_visibility_policy.dart';

void main() {
  test('restores only windows that were visible before fullscreen', () {
    final policy = WindowVisibilityPolicy();

    policy.setFullscreenSuppressed(true);
    expect(policy.shouldBeVisible, isFalse);
    policy.setFullscreenSuppressed(false);
    expect(policy.shouldBeVisible, isTrue);

    policy.requestHide();
    policy.setFullscreenSuppressed(true);
    policy.setFullscreenSuppressed(false);
    expect(policy.shouldBeVisible, isFalse);

    policy.requestShow();
    expect(policy.shouldBeVisible, isTrue);
  });
}
