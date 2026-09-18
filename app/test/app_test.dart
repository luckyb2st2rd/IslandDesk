import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/main.dart';

void main() {
  testWidgets('renders the development shell', (tester) async {
    await tester.pumpWidget(const IslandDeskApp());

    expect(find.text('IslandDesk development shell'), findsOneWidget);
  });
}

