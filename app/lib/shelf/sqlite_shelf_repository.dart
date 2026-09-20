import 'dart:io';

import 'package:islanddesk/shelf/shelf_item.dart';
import 'package:islanddesk/shelf/shelf_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteShelfRepository implements ShelfRepository {
  SqliteShelfRepository._(this._database) {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS shelf_items (
        id TEXT NOT NULL PRIMARY KEY,
        file_path TEXT NOT NULL UNIQUE,
        filename TEXT NOT NULL,
        extension TEXT NOT NULL,
        mime_type TEXT,
        file_size INTEGER NOT NULL CHECK (file_size >= 0),
        created_at INTEGER NOT NULL,
        pinned INTEGER NOT NULL CHECK (pinned IN (0, 1))
      ) STRICT
    ''');
  }

  final Database _database;

  static Future<SqliteShelfRepository> open() async {
    final supportDirectory = await getApplicationSupportDirectory();
    await supportDirectory.create(recursive: true);
    return openAtPath(
      path.join(supportDirectory.path, 'islanddesk_shelf.sqlite3'),
    );
  }

  static SqliteShelfRepository openAtPath(String databasePath) {
    if (databasePath != ':memory:') {
      Directory(path.dirname(databasePath)).createSync(recursive: true);
    }
    return SqliteShelfRepository._(sqlite3.open(databasePath));
  }

  @override
  Future<List<ShelfItem>> load() async {
    final rows = _database.select('''
      SELECT id, file_path, filename, extension, mime_type, file_size,
             created_at, pinned
      FROM shelf_items
      ORDER BY pinned DESC, created_at DESC
    ''');
    return rows
        .map(
          (row) => ShelfItem(
            id: row['id'] as String,
            filePath: row['file_path'] as String,
            filename: row['filename'] as String,
            extension: row['extension'] as String,
            mimeType: row['mime_type'] as String?,
            fileSize: row['file_size'] as int,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
              isUtc: true,
            ),
            pinned: row['pinned'] == 1,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(ShelfItem item) async {
    _database.execute(
      '''
        INSERT INTO shelf_items (
          id, file_path, filename, extension, mime_type, file_size,
          created_at, pinned
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(file_path) DO UPDATE SET
          filename = excluded.filename,
          extension = excluded.extension,
          mime_type = excluded.mime_type,
          file_size = excluded.file_size
      ''',
      [
        item.id,
        item.filePath,
        item.filename,
        item.extension,
        item.mimeType,
        item.fileSize,
        item.createdAt.toUtc().millisecondsSinceEpoch,
        item.pinned ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    _database.execute(
      'UPDATE shelf_items SET pinned = ? WHERE id = ?',
      [pinned ? 1 : 0, id],
    );
  }

  @override
  Future<void> replaceFile(ShelfItem item) async {
    _database.execute(
      '''
        UPDATE shelf_items SET
          file_path = ?, filename = ?, extension = ?, mime_type = ?,
          file_size = ?
        WHERE id = ?
      ''',
      [
        item.filePath,
        item.filename,
        item.extension,
        item.mimeType,
        item.fileSize,
        item.id,
      ],
    );
  }

  @override
  Future<void> remove(String id) async {
    _database.execute('DELETE FROM shelf_items WHERE id = ?', [id]);
  }

  @override
  Future<void> close() async => _database.close();
}
