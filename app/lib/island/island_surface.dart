import 'package:flutter/material.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';

class IslandSurface extends StatelessWidget {
  const IslandSurface({
    required this.controller,
    this.animationsEnabled = true,
    super.key,
  });

  static const animationDuration = Duration(milliseconds: 240);

  final IslandController controller;
  final bool animationsEnabled;

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
                        ? const _ExpandedContent(
                            key: ValueKey('expanded-content'),
                          )
                        : _CompactContent(
                            key: const ValueKey('compact-content'),
                            state: state,
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
  const _CompactContent({required this.state, super.key});

  final IslandState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.graphic_eq_rounded, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            state == IslandState.peek ? 'Open IslandDesk' : 'IslandDesk',
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
  const _ExpandedContent({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.music_note_rounded),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing playing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Connect a Windows media session',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ModuleAction(icon: Icons.content_copy_rounded, label: 'Clipboard'),
            _ModuleAction(icon: Icons.folder_copy_rounded, label: 'Shelf'),
            _ModuleAction(icon: Icons.timer_outlined, label: 'Timer'),
            _ModuleAction(icon: Icons.note_alt_outlined, label: 'Notes'),
          ],
        ),
      ],
    );
  }
}

class _ModuleAction extends StatelessWidget {
  const _ModuleAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: Colors.white70),
        const SizedBox(height: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }
}
