class ClipboardItem {
  const ClipboardItem({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.pinned,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final bool pinned;

  ClipboardItem copyWith({bool? pinned}) => ClipboardItem(
        id: id,
        text: text,
        createdAt: createdAt,
        pinned: pinned ?? this.pinned,
      );
}
