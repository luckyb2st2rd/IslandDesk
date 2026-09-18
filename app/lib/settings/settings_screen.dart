import 'package:flutter/material.dart';
import 'package:islanddesk/application/application_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final ApplicationController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFA111319),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _SettingsHeader(onClose: controller.showIsland),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  children: [
                    const _SectionTitle(
                      title: 'Behavior',
                      subtitle: 'Control how the island behaves on Windows.',
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      children: [
                        SwitchListTile.adaptive(
                          key: const ValueKey('always-on-top-setting'),
                          value: controller.alwaysOnTop,
                          onChanged: controller.setAlwaysOnTop,
                          secondary: const Icon(Icons.vertical_align_top),
                          title: const Text('Always on top'),
                          subtitle: const Text(
                            'Keep IslandDesk above regular application windows.',
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        SwitchListTile.adaptive(
                          key: const ValueKey('animations-setting'),
                          value: controller.animationsEnabled,
                          onChanged: controller.setAnimationsEnabled,
                          secondary: const Icon(Icons.animation_rounded),
                          title: const Text('Interface animations'),
                          subtitle: const Text(
                            'Animate transitions between island states.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: 'Modules',
                      subtitle:
                          'The first native integrations planned for the island.',
                    ),
                    const SizedBox(height: 12),
                    const _ModuleGrid(),
                    const SizedBox(height: 20),
                    Text(
                      'Settings are currently kept for this session. Persistent '
                      'storage will be connected in the next iteration.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 14, 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6977E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.blur_on_rounded, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IslandDesk Settings',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Windows preview',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('close-settings'),
            tooltip: 'Back to island',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  @override
  Widget build(BuildContext context) {
    const modules = [
      (Icons.music_note_rounded, 'Media'),
      (Icons.content_copy_rounded, 'Clipboard'),
      (Icons.folder_copy_rounded, 'Shelf'),
      (Icons.timer_outlined, 'Timer'),
      (Icons.note_alt_outlined, 'Notes'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final module in modules)
          Chip(
            avatar: Icon(module.$1, size: 17),
            label: Text(module.$2),
            side: const BorderSide(color: Colors.white10),
            backgroundColor: Colors.white.withValues(alpha: 0.045),
          ),
      ],
    );
  }
}
