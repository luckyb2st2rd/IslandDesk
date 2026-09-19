import 'dart:io';
import 'dart:typed_data';

import 'package:islanddesk/clipboard/clipboard_item.dart';
import 'package:islanddesk/clipboard/clipboard_repository.dart';
import 'package:islanddesk/src/rust/api/clipboard.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

abstract interface class ClipboardCrypto {
  ClipboardEncryptedData encrypt(String id, String text);

  String decrypt(String id, Uint8List nonce, Uint8List ciphertext);
}

class RustClipboardCrypto implements ClipboardCrypto {
  const RustClipboardCrypto();

  @override
  ClipboardEncryptedData encrypt(String id, String text) =>
      encryptClipboardText(itemId: id, plaintext: text);

  @override
  String decrypt(String id, Uint8List nonce, Uint8List ciphertext) =>
      decryptClipboardText(
        itemId: id,
        nonce: nonce,
        ciphertext: ciphertext,
      );
}

class SqliteClipboardRepository implements ClipboardRepository {
  SqliteClipboardRepository._(
    this._database,
    this._crypto, {
    required this.maxUnpinnedItems,
  }) {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS clipboard_items (
        id TEXT NOT NULL PRIMARY KEY,
        nonce BLOB NOT NULL,
        ciphertext BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        pinned INTEGER NOT NULL CHECK (pinned IN (0, 1))
      ) STRICT
    ''');
  }

  final Database _database;
  final ClipboardCrypto _crypto;
  final int maxUnpinnedItems;

  static Future<SqliteClipboardRepository> open({
    ClipboardCrypto crypto = const RustClipboardCrypto(),
    int maxUnpinnedItems = 50,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    await supportDirectory.create(recursive: true);
    return openAtPath(
      path.join(supportDirectory.path, 'islanddesk_clipboard.sqlite3'),
      crypto: crypto,
      maxUnpinnedItems: maxUnpinnedItems,
    );
  }

  static SqliteClipboardRepository openAtPath(
    String databasePath, {
    required ClipboardCrypto crypto,
    int maxUnpinnedItems = 50,
  }) {
    if (databasePath != ':memory:') {
      Directory(path.dirname(databasePath)).createSync(recursive: true);
    }
    return SqliteClipboardRepository._(
      sqlite3.open(databasePath),
      crypto,
      maxUnpinnedItems: maxUnpinnedItems,
    );
  }

  @override
  Future<List<ClipboardItem>> load() async {
    final rows = _database.select('''
      SELECT id, nonce, ciphertext, created_at, pinned
      FROM clipboard_items
      ORDER BY pinned DESC, created_at DESC
    ''');
    final items = <ClipboardItem>[];
    for (final row in rows) {
      try {
        final id = row['id'] as String;
        items.add(
          ClipboardItem(
            id: id,
            text: _crypto.decrypt(
              id,
              row['nonce'] as Uint8List,
              row['ciphertext'] as Uint8List,
            ),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
              isUtc: true,
            ),
            pinned: row['pinned'] == 1,
          ),
        );
      } catch (_) {
        // Authentication failures remain quarantined in encrypted storage and
        // are never exposed as partially decoded clipboard content.
      }
    }
    return items;
  }

  @override
  Future<void> save(ClipboardItem item) async {
    final encrypted = _crypto.encrypt(item.id, item.text);
    _database.execute(
      '''
        INSERT INTO clipboard_items (
          id, nonce, ciphertext, created_at, pinned
        ) VALUES (?, ?, ?, ?, ?)
      ''',
      [
        item.id,
        encrypted.nonce,
        encrypted.ciphertext,
        item.createdAt.toUtc().millisecondsSinceEpoch,
        item.pinned ? 1 : 0,
      ],
    );
    _database.execute(
      '''
        DELETE FROM clipboard_items
        WHERE pinned = 0 AND id NOT IN (
          SELECT id FROM clipboard_items
          WHERE pinned = 0
          ORDER BY created_at DESC
          LIMIT ?
        )
      ''',
      [maxUnpinnedItems],
    );
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    _database.execute(
      'UPDATE clipboard_items SET pinned = ? WHERE id = ?',
      [pinned ? 1 : 0, id],
    );
  }

  @override
  Future<void> remove(String id) async {
    _database.execute('DELETE FROM clipboard_items WHERE id = ?', [id]);
  }

  @override
  Future<void> clearUnpinned() async {
    _database.execute('DELETE FROM clipboard_items WHERE pinned = 0');
  }

  @override
  Future<void> close() async => _database.close();
}
