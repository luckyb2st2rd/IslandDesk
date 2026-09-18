import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/island/island_state.dart';

void main() {
  test('forwards island changes and switches application views', () {
    final controller = ApplicationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.island.toggleExpanded();
    expect(controller.island.state, IslandState.expanded);
    expect(notifications, 1);

    controller.showSettings();
    expect(controller.view, ApplicationView.settings);
    expect(notifications, 2);

    controller.showIsland();
    expect(controller.view, ApplicationView.island);
    expect(controller.island.state, IslandState.collapsed);

    controller.dispose();
  });

  test('updates session settings', () {
    final controller = ApplicationController();

    controller.setAlwaysOnTop(false);
    controller.setAnimationsEnabled(false);

    expect(controller.alwaysOnTop, isFalse);
    expect(controller.animationsEnabled, isFalse);

    controller.dispose();
  });
}
