import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/shelf/shelf_item.dart';

class ShelfView extends StatefulWidget {
  const ShelfView({
    required this.controller,
    required this.dropEnabled,
    this.onDragEntered,
    this.onDragExited,
    super.key,
  });

  final ShelfController controller;
  final bool dropEnabled;
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;

  @override
  State<ShelfView> createState() => _ShelfViewState();
}

class _ShelfViewState extends State<ShelfView> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: widget.dropEnabled,
      onDragEntered: (_) {
        setState(() => _dragging = true);
        widget.onDragEntered?.call();
      },
      onDragExited: (_) {
        setState(() => _dragging = false);
        widget.onDragExited?.call();
      },
      onDragDone: (details) {
        setState(() => _dragging = false);
        widget.onDragEntered?.call();
        unawaited(widget.controller.addPaths(
          details.files.whereType<DropItemFile>().map((item) => item.path),
        ));
      },
      child: AnimatedContainer(
        key: const ValueKey('shelf-drop-zone'),
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _dragging
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _dragging
                ? Theme.of(context).colorScheme.primary
                : Colors.white10,
          ),
        ),
        child: Column(
          children: [
            _ShelfHeader(dragging: _dragging),
            if (widget.controller.errorMessage case final message?) ...[
              const SizedBox(height: 6),
              Text(
                message,
                key: const ValueKey('shelf-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 6),
            Expanded(
              child: widget.controller.items.isEmpty
                  ? const _EmptyShelf()
                  : ListView.separated(
                      itemCount: widget.controller.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _ShelfItemTile(
                        item: widget.controller.items[index],
                        onTogglePinned: () => unawaited(
                          widget.controller.togglePinned(
                            widget.controller.items[index].id,
                          ),
                        ),
                        onRemove: () => unawaited(
                          widget.controller.remove(
                            widget.controller.items[index].id,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.dragging});

  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          dragging ? Icons.file_download_done_rounded : Icons.add_rounded,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          dragging ? 'Release to add files' : 'Drop files from Explorer here',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 38, color: Colors.white38),
          SizedBox(height: 8),
          Text('File Shelf is empty', key: ValueKey('shelf-empty')),
          SizedBox(height: 4),
          Text(
            'Only a reference is stored; the original file stays in place.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _ShelfItemTile extends StatelessWidget {
  const _ShelfItemTile({
    required this.item,
    required this.onTogglePinned,
    required this.onRemove,
  });

  final ShelfItem item;
  final VoidCallback onTogglePinned;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: item.filePath,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatBytes(item.fileSize),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('shelf-pin-${item.id}'),
            tooltip: item.pinned ? 'Unpin' : 'Pin',
            onPressed: onTogglePinned,
            icon: Icon(
              item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 19,
            ),
          ),
          IconButton(
            key: ValueKey('shelf-remove-${item.id}'),
            tooltip: 'Remove from shelf',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
