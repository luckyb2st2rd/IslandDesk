import 'package:flutter/material.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_surface.dart';

class IslandScreen extends StatelessWidget {
  const IslandScreen({
    required this.controller,
    this.animationsEnabled = true,
    super.key,
  });

  final IslandController controller;
  final bool animationsEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 34),
        child: Align(
          alignment: Alignment.topCenter,
          child: IslandSurface(
            controller: controller,
            animationsEnabled: animationsEnabled,
          ),
        ),
      ),
    );
  }
}
