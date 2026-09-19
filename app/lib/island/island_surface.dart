import 'dart:async';

import 'package:flutter/material.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/media/media_controller.dart';

class IslandSurface extends StatelessWidget {
  const IslandSurface({
    required this.controller,
    required this.mediaController,
    this.animationsEnabled = true,
    this.coreStatusLabel = 'Rust core preview',
    super.key,
  });

  static const animationDuration = Duration(milliseconds: 240);

  final IslandController controller;
  final MediaController mediaController;
  final bool animationsEnabled;
  final String coreStatusLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final size = state.surfaceSize;
        final transitionDuration =
            animationsEnabled ? animationDuration : Duration.zero;

        return AnimatedOpacity(
          duration: transitionDuration,
          opacity: state.isVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !state.isVisible,
            child: MouseRegion(
              onEnter: (_) => controller.pointerEntered(),
              onExit: (_) => controller.pointerExited(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.toggleExpanded,
                child: AnimatedContainer(
                  key: const ValueKey('island-surface'),
                  duration: transitionDuration,
                  curve: Curves.easeOutCubic,
                  width: size.width,
                  height: size.height,
                  padding: EdgeInsets.symmetric(
                    horizontal: state.showsDetails ? 18 : 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF20A0B0F),
                    borderRadius: BorderRadius.circular(
                      state.showsDetails ? 28 : 24,
                    ),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: animationsEnabled
                        ? const Duration(milliseconds: 160)
                        : Duration.zero,
                    child: state.showsDetails
                        ? _ExpandedContent(
                            key: ValueKey('expanded-content'),
                            mediaController: mediaController,
                            coreStatusLabel: coreStatusLabel,
                          )
                        : _CompactContent(
                            key: const ValueKey('compact-content'),
                            state: state,
                            mediaController: mediaController,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompactContent extends StatelessWidget {
  const _CompactContent({
    required this.state,
    required this.mediaController,
    super.key,
  });

  final IslandState state;
  final MediaController mediaController;

  @override
  Widget build(BuildContext context) {
    final session = mediaController.session;
    return Row(
      children: [
        Icon(
          session == null ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            session?.title.isNotEmpty == true
                ? session!.title
                : state == IslandState.peek
                    ? 'Open IslandDesk'
                    : 'IslandDesk',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      ],
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.mediaController,
    required this.coreStatusLabel,
    super.key,
  });

  final MediaController mediaController;
  final String coreStatusLabel;

  @override
  Widget build(BuildContext context) {
    final session = mediaController.session;
    final duration = session?.durationMs.toDouble() ?? 0;
    final position = session?.positionMs.toDouble() ?? 0;
    final progress =
        duration <= 0 ? 0.0 : (position / duration).clamp(0.0, 1.0);
    final subtitle = switch (session) {
      null when mediaController.errorMessage != null =>
        'Windows media service unavailable',
      null => coreStatusLabel,
      _ when session.artist.isNotEmpty => session.artist,
      _ => session.sourceAppId,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF6977E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                session == null
                    ? Icons.music_off_rounded
                    : Icons.music_note_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session?.title.isNotEmpty == true
                        ? session!.title
                        : 'Nothing playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          key: const ValueKey('media-progress'),
          value: progress,
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
          backgroundColor: Colors.white12,
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('media-previous'),
              tooltip: 'Previous',
              onPressed: session?.capabilities.canPrevious == true
                  ? () => unawaited(mediaController.previous())
                  : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              key: const ValueKey('media-play-pause'),
              onPressed: session != null &&
                      (session.capabilities.canPlay ||
                          session.capabilities.canPause)
                  ? () => unawaited(mediaController.playPause())
                  : null,
              icon: Icon(
                mediaController.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(mediaController.isPlaying ? 'Pause' : 'Play'),
            ),
            const SizedBox(width: 10),
            IconButton(
              key: const ValueKey('media-next'),
              tooltip: 'Next',
              onPressed: session?.capabilities.canNext == true
                  ? () => unawaited(mediaController.next())
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
