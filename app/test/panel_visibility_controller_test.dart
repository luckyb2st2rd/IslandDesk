import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/panel_visibility_controller.dart';

void main() {
  test('hides after its delay and cancels on re-entry', () async {
    final defaults = PanelVisibilityController();
    expect(defaults.hideDelay, const Duration(milliseconds: 1500));
    defaults.dispose();

    final controller = PanelVisibilityController(
      hideDelay: const Duration(milliseconds: 30),
    );
    controller.reveal();
    expect(controller.isHidden, isFalse);

    controller.pointerExited();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    controller.pointerEntered();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.isHidden, isFalse);

    controller.pointerExited();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.isHidden, isTrue);
    controller.dispose();
  });
}
