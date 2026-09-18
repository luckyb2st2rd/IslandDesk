import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';

void main() {
  testWidgets('changes settings and returns to the island', (tester) async {
    final controller = ApplicationController()..showSettings();

    await tester.pumpWidget(IslandDeskApp(controller: controller));

    expect(find.text('IslandDesk Settings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('animations-setting')));
    await tester.pump();
    expect(controller.animationsEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('close-settings')));
    await tester.pump();
    expect(find.text('IslandDesk Settings'), findsNothing);
    expect(find.text('IslandDesk'), findsWidgets);

    controller.dispose();
  });
}
