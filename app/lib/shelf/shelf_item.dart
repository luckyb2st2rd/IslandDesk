class ShelfItem {
  const ShelfItem({
    required this.id,
    required this.filePath,
    required this.filename,
    required this.extension,
    required this.fileSize,
    required this.createdAt,
    required this.pinned,
    this.mimeType,
  });

  final String id;
  final String filePath;
  final String filename;
  final String extension;
  final int fileSize;
  final DateTime createdAt;
  final bool pinned;
  final String? mimeType;

  ShelfItem copyWith({bool? pinned}) {
    return ShelfItem(
      id: id,
      filePath: filePath,
      filename: filename,
      extension: extension,
      fileSize: fileSize,
      createdAt: createdAt,
      pinned: pinned ?? this.pinned,
      mimeType: mimeType,
    );
  }
}
