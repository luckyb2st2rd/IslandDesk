import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/shelf/shelf_item.dart';
import 'package:islanddesk/shelf/sqlite_shelf_repository.dart';

void main() {
  test('persists, pins and removes shelf metadata', () async {
    final repository = SqliteShelfRepository.openAtPath(':memory:');
    final item = ShelfItem(
      id: 'shelf-1',
      filePath: 'C:/Documents/example.txt',
      filename: 'example.txt',
      extension: 'txt',
      mimeType: 'text/plain',
      fileSize: 42,
      createdAt: DateTime.utc(2026, 9, 19),
      pinned: false,
    );

    await repository.save(item);
    var loaded = await repository.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.filename, 'example.txt');
    expect(loaded.single.fileSize, 42);
    expect(loaded.single.pinned, isFalse);

    await repository.setPinned(item.id, true);
    loaded = await repository.load();
    expect(loaded.single.pinned, isTrue);

    await repository.replaceFile(
      loaded.single.copyWith(
        filePath: 'C:/Documents/relinked.md',
        filename: 'relinked.md',
        extension: 'md',
        fileSize: 84,
      ),
    );
    loaded = await repository.load();
    expect(loaded.single.filename, 'relinked.md');
    expect(loaded.single.fileSize, 84);

    await repository.remove(item.id);
    expect(await repository.load(), isEmpty);
    await repository.close();
  });
}
