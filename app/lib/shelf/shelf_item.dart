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
    this.isMissing = false,
  });

  final String id;
  final String filePath;
  final String filename;
  final String extension;
  final int fileSize;
  final DateTime createdAt;
  final bool pinned;
  final String? mimeType;
  final bool isMissing;

  ShelfItem copyWith({
    String? filePath,
    String? filename,
    String? extension,
    int? fileSize,
    bool? pinned,
    bool? isMissing,
  }) {
    return ShelfItem(
      id: id,
      filePath: filePath ?? this.filePath,
      filename: filename ?? this.filename,
      extension: extension ?? this.extension,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt,
      pinned: pinned ?? this.pinned,
      mimeType: mimeType,
      isMissing: isMissing ?? this.isMissing,
    );
  }
}
