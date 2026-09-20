import 'dart:io';

import 'package:islanddesk/launcher/launcher_item.dart';
import 'package:islanddesk/launcher/launcher_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteLauncherRepository implements LauncherRepository {
  SqliteLauncherRepository._(this._database) {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS launcher_items (
        id TEXT NOT NULL PRIMARY KEY,
        executable_path TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        arguments TEXT,
        working_directory TEXT,
        position INTEGER NOT NULL CHECK (position >= 0),
        created_at INTEGER NOT NULL
      ) STRICT
    ''');
  }

  final Database _database;

  static Future<SqliteLauncherRepository> open() async {
    final supportDirectory = await getApplicationSupportDirectory();
    await supportDirectory.create(recursive: true);
    return openAtPath(
      path.join(supportDirectory.path, 'islanddesk_launcher.sqlite3'),
    );
  }

  static SqliteLauncherRepository openAtPath(String databasePath) {
    if (databasePath != ':memory:') {
      Directory(path.dirname(databasePath)).createSync(recursive: true);
    }
    return SqliteLauncherRepository._(sqlite3.open(databasePath));
  }

  @override
  Future<List<LauncherItem>> load() async => _database
      .select('''
        SELECT id, executable_path, display_name, arguments,
               working_directory, position, created_at
        FROM launcher_items
        ORDER BY position ASC, created_at ASC
      ''')
      .map(
        (row) => LauncherItem(
          id: row['id'] as String,
          executablePath: row['executable_path'] as String,
          displayName: row['display_name'] as String,
          arguments: row['arguments'] as String?,
          workingDirectory: row['working_directory'] as String?,
          position: row['position'] as int,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
            isUtc: true,
          ),
        ),
      )
      .toList(growable: false);

  @override
  Future<void> save(LauncherItem item) async {
    _database.execute(
      '''
        INSERT INTO launcher_items (
          id, executable_path, display_name, arguments,
          working_directory, position, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        item.id,
        item.executablePath,
        item.displayName,
        item.arguments,
        item.workingDirectory,
        item.position,
        item.createdAt.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> reorder(List<String> ids) async {
    _database.execute('BEGIN IMMEDIATE');
    try {
      for (var position = 0; position < ids.length; position++) {
        _database.execute(
          'UPDATE launcher_items SET position = ? WHERE id = ?',
          [position, ids[position]],
        );
      }
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> remove(String id) async {
    _database.execute('DELETE FROM launcher_items WHERE id = ?', [id]);
  }

  @override
  Future<void> close() async => _database.close();
}
