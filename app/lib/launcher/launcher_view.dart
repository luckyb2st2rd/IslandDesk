import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:islanddesk/launcher/launcher_controller.dart';
import 'package:islanddesk/launcher/launcher_item.dart';

class LauncherView extends StatelessWidget {
  const LauncherView({required this.controller, super.key});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('launcher-content'),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'App Launcher',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Refresh application paths',
              onPressed: () => unawaited(controller.refreshAvailability()),
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton.icon(
              key: const ValueKey('launcher-add'),
              onPressed: _chooseApplication,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (controller.errorMessage case final message?) ...[
          const SizedBox(height: 4),
          Text(
            message,
            key: const ValueKey('launcher-error'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Expanded(
          child: controller.items.isEmpty
              ? const _EmptyLauncher()
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: controller.items.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      unawaited(controller.reorder(oldIndex, newIndex)),
                  itemBuilder: (context, index) {
                    final item = controller.items[index];
                    return _LauncherTile(
                      key: ValueKey('launcher-item-${item.id}'),
                      item: item,
                      index: index,
                      launchSupported: controller.isSupported,
                      onLaunch: () => unawaited(controller.launch(item.id)),
                      onRemove: () => unawaited(controller.remove(item.id)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _chooseApplication() async {
    final selection = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Applications',
          extensions: ['exe', 'lnk', 'com', 'bat', 'cmd'],
        ),
      ],
    );
    if (selection != null) await controller.addPath(selection.path);
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({
    required this.item,
    required this.index,
    required this.launchSupported,
    required this.onLaunch,
    required this.onRemove,
    super.key,
  });

  final LauncherItem item;
  final int index;
  final bool launchSupported;
  final VoidCallback onLaunch;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: Colors.white.withValues(alpha: 0.045),
      child: ListTile(
        dense: true,
        onTap: item.isMissing || !launchSupported ? null : onLaunch,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: item.isMissing
              ? Colors.white10
              : Theme.of(context).colorScheme.primaryContainer,
          child: item.isMissing
              ? const Icon(Icons.link_off_rounded, size: 19)
              : Text(
                  item.displayName.isEmpty
                      ? '?'
                      : item.displayName.characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        title: Text(
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.isMissing ? 'Application not found' : item.executablePath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('launcher-remove-${item.id}'),
              tooltip: 'Remove from launcher',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLauncher extends StatelessWidget {
  const _EmptyLauncher();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rocket_launch_outlined, size: 38, color: Colors.white54),
          SizedBox(height: 8),
          Text('Add frequently used applications'),
          SizedBox(height: 4),
          Text(
            'Drag the handles to keep them in your preferred order.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
