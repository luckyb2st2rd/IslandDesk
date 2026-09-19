import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:islanddesk/island/island_controller.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/shelf/shelf_view.dart';

class IslandSurface extends StatelessWidget {
  const IslandSurface({
    required this.controller,
    required this.mediaController,
    required this.shelfController,
    this.animationsEnabled = true,
    this.coreStatusLabel = 'Rust core preview',
    this.onPointerEntered,
    this.onPointerExited,
    super.key,
  });

  static const animationDuration = Duration(milliseconds: 240);

  final IslandController controller;
  final MediaController mediaController;
  final ShelfController shelfController;
  final bool animationsEnabled;
  final String coreStatusLabel;
  final VoidCallback? onPointerEntered;
  final VoidCallback? onPointerExited;

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
              onEnter: (_) {
                controller.pointerEntered();
                onPointerEntered?.call();
              },
              onExit: (_) {
                controller.pointerExited();
                onPointerExited?.call();
              },
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
                            controller: controller,
                            mediaController: mediaController,
                            shelfController: shelfController,
                            coreStatusLabel: coreStatusLabel,
                            onPointerEntered: onPointerEntered,
                            onPointerExited: onPointerExited,
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
    required this.controller,
    required this.mediaController,
    required this.shelfController,
    required this.coreStatusLabel,
    this.onPointerEntered,
    this.onPointerExited,
    super.key,
  });

  final IslandController controller;
  final MediaController mediaController;
  final ShelfController shelfController;
  final String coreStatusLabel;
  final VoidCallback? onPointerEntered;
  final VoidCallback? onPointerExited;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedModule;
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ModuleButton(
                  key: const ValueKey('module-media'),
                  icon: Icons.music_note_rounded,
                  label: 'Media',
                  selected: selected == IslandModule.media,
                  onPressed: () => controller.selectModule(IslandModule.media),
                ),
                _ModuleButton(
                  key: const ValueKey('module-shelf'),
                  icon: Icons.inventory_2_outlined,
                  label: 'Shelf',
                  selected: selected == IslandModule.shelf,
                  onPressed: () => controller.selectModule(IslandModule.shelf),
                ),
                _ModuleButton(
                  key: const ValueKey('module-clipboard'),
                  icon: Icons.content_copy_rounded,
                  label: 'Clipboard',
                  selected: selected == IslandModule.clipboard,
                  onPressed: () =>
                      controller.selectModule(IslandModule.clipboard),
                ),
                _ModuleButton(
                  key: const ValueKey('module-timer'),
                  icon: Icons.timer_outlined,
                  label: 'Timer',
                  selected: selected == IslandModule.timer,
                  onPressed: () => controller.selectModule(IslandModule.timer),
                ),
                _ModuleButton(
                  key: const ValueKey('module-notes'),
                  icon: Icons.note_alt_outlined,
                  label: 'Notes',
                  selected: selected == IslandModule.notes,
                  onPressed: () => controller.selectModule(IslandModule.notes),
                ),
                _ModuleButton(
                  key: const ValueKey('module-launcher'),
                  icon: Icons.rocket_launch_outlined,
                  label: 'Apps',
                  selected: selected == IslandModule.launcher,
                  onPressed: () =>
                      controller.selectModule(IslandModule.launcher),
                ),
                _ModuleButton(
                  key: const ValueKey('module-system'),
                  icon: Icons.tune_rounded,
                  label: 'System',
                  selected: selected == IslandModule.system,
                  onPressed: () => controller.selectModule(IslandModule.system),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 14, color: Colors.white12),
        Expanded(
          child: IndexedStack(
            index: selected.index,
            children: [
              _MediaModule(
                mediaController: mediaController,
                coreStatusLabel: coreStatusLabel,
              ),
              ShelfView(
                key: const ValueKey('shelf-content'),
                controller: shelfController,
                dropEnabled: selected == IslandModule.shelf,
                onDragEntered: onPointerEntered,
                onDragExited: onPointerExited,
              ),
              const _ClipboardModule(),
              const _TimerModule(),
              const _NotesModule(),
              const _ComingSoonModule(
                key: ValueKey('launcher-content'),
                icon: Icons.rocket_launch_outlined,
                title: 'App Launcher',
                description:
                    'Pinned applications and their shortcuts will appear '
                    'here after launcher persistence is connected.',
              ),
              const _ComingSoonModule(
                key: ValueKey('system-content'),
                icon: Icons.tune_rounded,
                title: 'System Controls',
                description:
                    'Volume, audio device and Keep Awake require the next '
                    'native Windows services.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.white54,
          backgroundColor: selected ? Colors.white10 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ComingSoonModule extends StatelessWidget {
  const _ComingSoonModule({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaModule extends StatelessWidget {
  const _MediaModule({
    required this.mediaController,
    required this.coreStatusLabel,
  });

  final MediaController mediaController;
  final String coreStatusLabel;

  @override
  Widget build(BuildContext context) {
    final session = mediaController.session;
    final duration = session?.durationMs.toDouble() ?? 0;
    final position = mediaController.displayPositionMs.toDouble();
    final progress =
        duration <= 0 ? 0.0 : (position / duration).clamp(0.0, 1.0);
    final subtitle = switch (session) {
      null when mediaController.errorMessage != null =>
        'Windows media service unavailable',
      null => coreStatusLabel,
      _ when session.artist.isNotEmpty => session.artist,
      _ when session.sourceAppName.isNotEmpty => session.sourceAppName,
      _ => session.sourceAppId,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              key: const ValueKey('media-artwork'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF6977E8),
                ),
                child: session?.artwork.isNotEmpty == true
                    ? Image.memory(
                        session!.artwork,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.music_note_rounded),
                      )
                    : Icon(
                        session == null
                            ? Icons.music_off_rounded
                            : Icons.music_note_rounded,
                      ),
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
        const SizedBox(height: 8),
        SizedBox(
          height: 24,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              key: const ValueKey('media-progress'),
              value: progress,
              onChanged: session?.capabilities.canSeek == true
                  ? (value) =>
                      mediaController.previewSeek((duration * value).round())
                  : null,
              onChangeEnd: session?.capabilities.canSeek == true
                  ? (value) => unawaited(
                        mediaController.seek((duration * value).round()),
                      )
                  : null,
            ),
          ),
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

class _ClipboardModule extends StatefulWidget {
  const _ClipboardModule();

  @override
  State<_ClipboardModule> createState() => _ClipboardModuleState();
}

class _ClipboardModuleState extends State<_ClipboardModule> {
  String _text = 'Press refresh to read the clipboard';
  bool _loading = false;
  bool _hasClipboardText = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      setState(() {
        final value = data?.text?.trim();
        _text = value == null || value.isEmpty ? 'Clipboard is empty' : value;
        _hasClipboardText = value != null && value.isNotEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _text = 'Clipboard is unavailable';
          _hasClipboardText = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Current clipboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              key: const ValueKey('clipboard-refresh'),
              tooltip: 'Refresh clipboard',
              onPressed: _loading ? null : _refresh,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              key: const ValueKey('clipboard-copy'),
              tooltip: 'Copy again',
              onPressed: _hasClipboardText
                  ? () => Clipboard.setData(ClipboardData(text: _text))
                  : null,
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _text,
                key: const ValueKey('clipboard-content'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'History will be added after encrypted storage is ready.',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }
}

class _NotesModule extends StatefulWidget {
  const _NotesModule();

  @override
  State<_NotesModule> createState() => _NotesModuleState();
}

class _NotesModuleState extends State<_NotesModule> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Quick note',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('Session only'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            key: const ValueKey('notes-editor'),
            controller: _controller,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Write a note…',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.045),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerModule extends StatefulWidget {
  const _TimerModule();

  @override
  State<_TimerModule> createState() => _TimerModuleState();
}

class _TimerModuleState extends State<_TimerModule> {
  Timer? _ticker;
  int _durationSeconds = 300;
  int _remainingSeconds = 300;
  bool _running = false;

  void _selectDuration(int seconds) {
    _ticker?.cancel();
    setState(() {
      _durationSeconds = seconds;
      _remainingSeconds = seconds;
      _running = false;
    });
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remainingSeconds == 0) _remainingSeconds = _durationSeconds;
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _running = false;
          _ticker?.cancel();
        }
      });
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _remainingSeconds = _durationSeconds;
      _running = false;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Text(
          '$minutes:$seconds',
          key: const ValueKey('timer-value'),
          style: const TextStyle(
            fontSize: 52,
            height: 1,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in const [300, 600, 1500])
              ChoiceChip(
                label: Text('${preset ~/ 60} min'),
                selected: _durationSeconds == preset,
                onSelected: (_) => _selectDuration(preset),
              ),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('timer-toggle'),
              onPressed: _toggle,
              icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow),
              label: Text(_running ? 'Pause' : 'Start'),
            ),
            const SizedBox(width: 10),
            IconButton(
              key: const ValueKey('timer-reset'),
              tooltip: 'Reset timer',
              onPressed: _reset,
              icon: const Icon(Icons.replay_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
