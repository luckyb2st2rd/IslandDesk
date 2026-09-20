import 'dart:async';

import 'package:flutter/material.dart';
import 'package:islanddesk/system_controls/system_controls_controller.dart';

class SystemControlsView extends StatelessWidget {
  const SystemControlsView({required this.controller, super.key});

  final SystemControlsController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (!controller.isSupported) {
      return const Center(
        key: ValueKey('system-content'),
        child: Text('System controls are currently available on Windows.'),
      );
    }
    if (state == null) {
      return Center(
        key: const ValueKey('system-content'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.errorMessage == null)
              const Icon(Icons.tune_rounded, size: 36, color: Colors.white54)
            else ...[
              const Icon(Icons.warning_amber_rounded, size: 36),
              const SizedBox(height: 10),
              const Text('Windows audio controls are unavailable'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => unawaited(controller.refresh()),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      key: const ValueKey('system-content'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        _SectionCard(
          icon: state.output.muted
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          title: 'Output volume',
          trailing: IconButton(
            key: const ValueKey('system-output-mute'),
            tooltip: state.output.muted ? 'Unmute output' : 'Mute output',
            onPressed: state.output.available
                ? () => unawaited(
                      controller.setOutputMuted(!state.output.muted),
                    )
                : null,
            icon: Icon(
              state.output.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
            ),
          ),
          child: state.output.available
              ? Row(
                  children: [
                    Expanded(
                      child: Slider(
                        key: const ValueKey('system-output-volume'),
                        value: state.output.volumePercent.toDouble(),
                        max: 100,
                        divisions: 100,
                        label: '${state.output.volumePercent}%',
                        onChanged: (value) =>
                            controller.previewOutputVolume(value.round()),
                        onChangeEnd: (value) => unawaited(
                          controller.setOutputVolume(value.round()),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${state.output.volumePercent}%',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                )
              : const Text('No default output device'),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          icon: state.input.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          title: 'Microphone',
          trailing: Switch(
            key: const ValueKey('system-input-mute'),
            value: state.input.muted,
            onChanged: state.input.available
                ? (muted) => unawaited(controller.setInputMuted(muted))
                : null,
          ),
          child: Text(
            state.input.available
                ? state.input.muted
                    ? 'Muted'
                    : 'Active • ${state.input.volumePercent}%'
                : 'No default input device',
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          icon: Icons.coffee_rounded,
          title: 'Keep Awake',
          trailing: Switch(
            key: const ValueKey('system-keep-awake'),
            value: state.keepAwake,
            onChanged: (active) => unawaited(controller.setKeepAwake(active)),
          ),
          child: Text(
            state.keepAwake
                ? 'Display and PC sleep are prevented while IslandDesk runs.'
                : 'Allow Windows to use its normal sleep settings.',
          ),
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 8),
          const Text(
            'A system command failed. The displayed state will refresh.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                trailing,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 29, right: 6),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
