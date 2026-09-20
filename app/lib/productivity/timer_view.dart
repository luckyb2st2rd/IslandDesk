import 'dart:async';

import 'package:flutter/material.dart';
import 'package:islanddesk/productivity/productivity_controller.dart';

class TimerView extends StatelessWidget {
  const TimerView({required this.controller, super.key});

  final ProductivityController controller;

  @override
  Widget build(BuildContext context) {
    final remaining = controller.timerRemainingSeconds;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
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
                selected: controller.timerDurationSeconds == preset,
                onSelected: (_) => unawaited(
                  controller.selectTimerDuration(preset),
                ),
              ),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('timer-toggle'),
              onPressed: () => unawaited(controller.toggleTimer()),
              icon: Icon(
                controller.timerRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow,
              ),
              label: Text(controller.timerRunning ? 'Pause' : 'Start'),
            ),
            const SizedBox(width: 10),
            IconButton(
              key: const ValueKey('timer-reset'),
              tooltip: 'Reset timer',
              onPressed: () => unawaited(controller.resetTimer()),
              icon: const Icon(Icons.replay_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
