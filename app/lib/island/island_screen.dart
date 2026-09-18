import 'package:flutter/material.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_surface.dart';

class IslandScreen extends StatelessWidget {
  const IslandScreen({required this.controller, super.key});

  final IslandController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11131A), Color(0xFF20263A)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _DevelopmentBackdrop()),
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 10),
                child: IslandSurface(controller: controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevelopmentBackdrop extends StatelessWidget {
  const _DevelopmentBackdrop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'IslandDesk',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Windows UI prototype',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white54,
                ),
          ),
        ],
      ),
    );
  }
}
