import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/shelf/shelf_item.dart';
import 'package:path/path.dart' as path;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
            _ShelfHeader(
              dragging: _dragging,
              onRefresh: () => unawaited(
                widget.controller.refreshAvailability(),
              ),
            ),
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
                        onMissing: () => widget.controller.markMissing(
                          widget.controller.items[index].id,
                        ),
                        onRelink: () => _chooseReplacement(
                          widget.controller.items[index],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseReplacement(ShelfItem item) async {
    final parent = path.dirname(item.filePath);
    final replacement = await openFile(
      initialDirectory: await Directory(parent).exists() ? parent : null,
      confirmButtonText: 'Relink',
    );
    if (replacement != null) {
      await widget.controller.relink(item.id, replacement.path);
    }
  }
}

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.dragging, required this.onRefresh});

  final bool dragging;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          dragging ? Icons.file_download_done_rounded : Icons.add_rounded,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            dragging
                ? 'Release to add files'
                : 'Drop files here • drag them out to export',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const ValueKey('shelf-refresh'),
          tooltip: 'Check file availability',
          onPressed: onRefresh,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh_rounded, size: 18),
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
    required this.onMissing,
    required this.onRelink,
  });

  final ShelfItem item;
  final VoidCallback onTogglePinned;
  final VoidCallback onRemove;
  final Future<void> Function() onMissing;
  final VoidCallback onRelink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: item.isMissing
                ? _fileLabel(context)
                : DragItemWidget(
                    key: ValueKey('shelf-drag-${item.id}'),
                    allowedOperations: () => [DropOperation.copy],
                    dragItemProvider: (_) async {
                      if (!await File(item.filePath).exists()) {
                        await onMissing();
                        return null;
                      }
                      final dragItem = DragItem(
                        suggestedName: item.filename,
                        localData: item.id,
                      );
                      dragItem.add(Formats.fileUri(Uri.file(item.filePath)));
                      return dragItem;
                    },
                    child: DraggableWidget(
                      hitTestBehavior: HitTestBehavior.opaque,
                      child: _fileLabel(context),
                    ),
                  ),
          ),
          if (item.isMissing)
            IconButton(
              key: ValueKey('shelf-relink-${item.id}'),
              tooltip: 'Locate replacement file',
              onPressed: onRelink,
              icon: const Icon(Icons.drive_file_move_outline, size: 19),
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

  Widget _fileLabel(BuildContext context) {
    return Tooltip(
      message: item.filePath,
      child: Row(
        children: [
          Icon(
            item.isMissing
                ? Icons.error_outline_rounded
                : Icons.insert_drive_file_outlined,
            color: item.isMissing
                ? Theme.of(context).colorScheme.error
                : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration:
                        item.isMissing ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  item.isMissing
                      ? 'File missing • ${_formatBytes(item.fileSize)}'
                      : _formatBytes(item.fileSize),
                  style: TextStyle(
                    fontSize: 11,
                    color: item.isMissing
                        ? Theme.of(context).colorScheme.error
                        : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isMissing)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 17,
                color: Colors.white24,
              ),
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
