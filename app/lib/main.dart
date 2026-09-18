import 'package:flutter/widgets.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/desktop/desktop_window_controller.dart';
import 'package:islanddesk/island/island_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final desktopWindow = DesktopWindowController();
  await desktopWindow.initialize(IslandState.collapsed);

  runApp(
    IslandDeskApp(onIslandStateChanged: desktopWindow.showState),
  );
}
