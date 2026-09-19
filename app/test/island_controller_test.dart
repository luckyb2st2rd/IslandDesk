import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';

void main() {
  group('IslandController', () {
    test('peeks on hover and collapses when the pointer exits', () {
      final controller = IslandController();

      controller.pointerEntered();
      expect(controller.state, IslandState.peek);

      controller.pointerExited();
      expect(controller.state, IslandState.collapsed);
    });

    test('toggles expanded state', () {
      final controller = IslandController();

      controller.toggleExpanded();
      expect(controller.state, IslandState.expanded);

      controller.toggleExpanded();
      expect(controller.state, IslandState.collapsed);
    });

    test('selects modules and expands the island', () {
      final controller = IslandController();

      controller.selectModule(IslandModule.notes);

      expect(controller.selectedModule, IslandModule.notes);
      expect(controller.state, IslandState.expanded);
      controller.dispose();
    });
  });
}
