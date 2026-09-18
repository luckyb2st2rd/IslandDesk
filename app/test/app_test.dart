import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/app.dart';

void main() {
  testWidgets('expands the island when clicked', (tester) async {
    await tester.pumpWidget(const IslandDeskApp());

    expect(find.text('IslandDesk'), findsWidgets);
    expect(find.text('Nothing playing'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('island-surface')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing playing'), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
  });
}
