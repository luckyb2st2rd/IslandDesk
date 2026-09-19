import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/settings/app_settings.dart';

void main() {
  testWidgets('changes settings and returns to the island', (tester) async {
    final controller = ApplicationController()..showSettings();

    await tester.pumpWidget(IslandDeskApp(controller: controller));

    expect(find.text('IslandDesk Settings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('animations-setting')));
    await tester.pump();
    expect(controller.animationsEnabled, isFalse);
    await tester.tap(
      find.byKey(const ValueKey('hide-in-fullscreen-setting')),
    );
    await tester.pump();
    expect(controller.hideInFullscreen, isFalse);

    final monitorMode = find.byKey(const ValueKey('monitor-mode-setting'));
    await tester.ensureVisible(monitorMode);
    await tester.tap(monitorMode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow active monitor').last);
    await tester.pumpAndSettle();
    expect(controller.monitorPreference, MonitorPreference.followActive);

    await tester.tap(find.byKey(const ValueKey('close-settings')));
    await tester.pump();
    expect(find.text('IslandDesk Settings'), findsNothing);
    expect(find.text('IslandDesk'), findsWidgets);

    controller.dispose();
  });
}
