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
                securityReady ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 14,
              ),
              label: Text(securityReady ? 'Protected' : 'History off'),
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
                        ? 'Copy text to add it here'
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
              ? 'Encrypted with AES-256-GCM; key protected by ${_backendLabel(securityBackend)}.'
              : 'History stays disabled until secure key storage is available.',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }

  static String _backendLabel(String backend) => switch (backend) {
        'windows_credential_manager' => 'Windows Credential Manager',
        _ => 'the operating system credential store',
      };
}
