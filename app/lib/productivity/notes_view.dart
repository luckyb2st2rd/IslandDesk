import 'package:flutter/material.dart';
import 'package:islanddesk/productivity/productivity_controller.dart';

class NotesView extends StatefulWidget {
  const NotesView({required this.controller, super.key});

  final ProductivityController controller;

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.noteText);
  }

  @override
  void didUpdateWidget(covariant NotesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_textController.text != widget.controller.noteText &&
        !_textController.selection.isValid) {
      _textController.text = widget.controller.noteText;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
                'Quick note',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                widget.controller.notePersistenceEnabled
                    ? Icons.lock_rounded
                    : Icons.edit_note_rounded,
                size: 15,
              ),
              label: Text(
                widget.controller.notePersistenceEnabled
                    ? 'Encrypted locally'
                    : 'Current session',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            key: const ValueKey('notes-editor'),
            controller: _textController,
            onChanged: widget.controller.updateNote,
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
