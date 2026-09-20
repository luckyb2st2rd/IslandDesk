import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:islanddesk/clipboard/clipboard_controller.dart';

class ClipboardView extends StatelessWidget {
  const ClipboardView({
    required this.controller,
    required this.securityReady,
    required this.securityBackend,
    super.key,
  });

  final ClipboardController controller;
  final bool securityReady;
  final String securityBackend;

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Clipboard history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                controller.capturePaused
                    ? Icons.pause_rounded
                    : securityReady
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                size: 14,
              ),
              label: Text(
                controller.capturePaused
                    ? 'Paused'
                    : securityReady
                        ? 'Protected'
                        : 'History off',
              ),
            ),
            IconButton(
              key: const ValueKey('clipboard-pause'),
              tooltip: controller.capturePaused
                  ? 'Resume clipboard capture'
                  : 'Pause clipboard capture',
              onPressed: securityReady
                  ? () => unawaited(
                        controller.setCapturePaused(!controller.capturePaused),
                      )
                  : null,
              icon: Icon(
                controller.capturePaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
            ),
            IconButton(
              key: const ValueKey('clipboard-exclusions'),
              tooltip: 'Sensitive application exclusions',
              onPressed: securityReady ? () => _showExclusions(context) : null,
              icon: const Icon(Icons.shield_outlined),
            ),
            IconButton(
              key: const ValueKey('clipboard-clear'),
              tooltip: 'Clear unpinned history',
              onPressed: items.any((item) => !item.pinned)
                  ? () => unawaited(controller.clearUnpinned())
                  : null,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ),
        if (controller.errorMessage case final error?)
          Text(error, style: const TextStyle(color: Colors.orangeAccent)),
        const SizedBox(height: 6),
        Expanded(
          child: items.isEmpty
              ? Center(
                  key: const ValueKey('clipboard-content'),
                  child: Text(
                    controller.isListening
                        ? controller.capturePaused
                            ? 'Clipboard capture is paused'
                            : 'Copy text to add it here'
                        : 'Secure clipboard history is unavailable',
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('clipboard-content'),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.045),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.text.replaceAll('\n', ' '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy',
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: item.text),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                          ),
                          IconButton(
                            tooltip: item.pinned ? 'Unpin' : 'Pin',
                            onPressed: () =>
                                unawaited(controller.togglePinned(item.id)),
                            icon: Icon(
                              item.pinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () =>
                                unawaited(controller.remove(item.id)),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 6),
        Text(
          securityReady
              ? 'AES-256-GCM • ${controller.excludedApplications.length} sensitive apps excluded • key in ${_backendLabel(securityBackend)}.'
              : 'History stays disabled until secure key storage is available.',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }

  Future<void> _showExclusions(BuildContext context) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _ClipboardExclusionsDialog(
        initialApplications: controller.excludedApplications,
      ),
    );
    if (result != null) {
      await controller.setExcludedApplications(result);
    }
  }

  static String _backendLabel(String backend) => switch (backend) {
        'windows_credential_manager' => 'Windows Credential Manager',
        _ => 'the operating system credential store',
      };
}

class _ClipboardExclusionsDialog extends StatefulWidget {
  const _ClipboardExclusionsDialog({required this.initialApplications});

  final List<String> initialApplications;

  @override
  State<_ClipboardExclusionsDialog> createState() =>
      _ClipboardExclusionsDialogState();
}

class _ClipboardExclusionsDialogState
    extends State<_ClipboardExclusionsDialog> {
  late final TextEditingController _editor;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController(
      text: widget.initialApplications.join('\n'),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sensitive applications'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Clipboard changes copied while one of these applications '
                'is active will not be saved.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('clipboard-exclusions-editor'),
                controller: _editor,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Executable names',
                  hintText: 'bitwarden.exe',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('clipboard-exclusions-save'),
          onPressed: () => Navigator.pop(
            context,
            _editor.text
                .split(RegExp(r'[,;\n]'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
