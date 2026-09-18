import 'package:flutter/material.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_screen.dart';

class IslandDeskApp extends StatefulWidget {
  const IslandDeskApp({super.key});

  @override
  State<IslandDeskApp> createState() => _IslandDeskAppState();
}

class _IslandDeskAppState extends State<IslandDeskApp> {
  late final IslandController _controller;

  @override
  void initState() {
    super.initState();
    _controller = IslandController();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      ),
      home: IslandScreen(controller: _controller),
    );
  }
}
