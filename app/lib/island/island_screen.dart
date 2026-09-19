import 'package:flutter/material.dart';
import 'package:islanddesk/clipboard/clipboard_controller.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_surface.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';

class IslandScreen extends StatelessWidget {
  const IslandScreen({
    required this.controller,
    required this.mediaController,
    required this.shelfController,
    required this.clipboardController,
    this.animationsEnabled = true,
    this.coreStatusLabel = 'Rust core preview',
    this.clipboardSecurityReady = false,
    this.clipboardSecurityBackend = 'unavailable',
    this.onPointerEntered,
    this.onPointerExited,
    super.key,
  });

  final IslandController controller;
  final MediaController mediaController;
  final ShelfController shelfController;
  final ClipboardController clipboardController;
  final bool animationsEnabled;
  final String coreStatusLabel;
  final bool clipboardSecurityReady;
  final String clipboardSecurityBackend;
  final VoidCallback? onPointerEntered;
  final VoidCallback? onPointerExited;

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
            mediaController: mediaController,
            shelfController: shelfController,
            clipboardController: clipboardController,
            animationsEnabled: animationsEnabled,
            coreStatusLabel: coreStatusLabel,
            clipboardSecurityReady: clipboardSecurityReady,
            clipboardSecurityBackend: clipboardSecurityBackend,
            onPointerEntered: onPointerEntered,
            onPointerExited: onPointerExited,
          ),
        ),
      ),
    );
  }
}
