import 'package:flutter/material.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/island/island_screen.dart';
import 'package:islanddesk/settings/settings_screen.dart';

class IslandDeskApp extends StatefulWidget {
  const IslandDeskApp({this.controller, super.key});

  final ApplicationController? controller;

  @override
  State<IslandDeskApp> createState() => _IslandDeskAppState();
}

class _IslandDeskAppState extends State<IslandDeskApp> {
  late final ApplicationController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ApplicationController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IslandDesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C8CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => switch (_controller.view) {
          ApplicationView.island => IslandScreen(
              controller: _controller.island,
              animationsEnabled: _controller.animationsEnabled,
              coreStatusLabel: _controller.coreStatusLabel,
            ),
          ApplicationView.settings => SettingsScreen(
              controller: _controller,
            ),
        },
      ),
    );
  }
}
