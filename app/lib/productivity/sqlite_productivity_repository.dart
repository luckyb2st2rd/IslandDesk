import 'dart:io';
import 'dart:typed_data';

import 'package:islanddesk/productivity/productivity_repository.dart';
import 'package:islanddesk/productivity/productivity_snapshot.dart';
import 'package:islanddesk/src/rust/api/clipboard.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

abstract interface class ProductivityCrypto {
  ClipboardEncryptedData encrypt(String id, String text);

  String decrypt(String id, Uint8List nonce, Uint8List ciphertext);
}

class RustProductivityCrypto implements ProductivityCrypto {
  const RustProductivityCrypto();

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

class SqliteProductivityRepository implements ProductivityRepository {
  SqliteProductivityRepository._(this._database, this._crypto) {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS quick_note (
        singleton INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
        nonce BLOB NOT NULL,
        ciphertext BLOB NOT NULL,
        updated_at INTEGER NOT NULL
      ) STRICT
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS timer_state (
        singleton INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
        duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
        remaining_seconds INTEGER NOT NULL CHECK (remaining_seconds >= 0),
        end_at INTEGER,
        running INTEGER NOT NULL CHECK (running IN (0, 1))
      ) STRICT
    ''');
  }

  final Database _database;
  final ProductivityCrypto _crypto;
  static const _noteId = 'productivity.quick-note.v1';

  static Future<SqliteProductivityRepository> open({
    ProductivityCrypto crypto = const RustProductivityCrypto(),
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    await supportDirectory.create(recursive: true);
    return openAtPath(
      path.join(supportDirectory.path, 'islanddesk_productivity.sqlite3'),
      crypto: crypto,
    );
  }

  static SqliteProductivityRepository openAtPath(
    String databasePath, {
    required ProductivityCrypto crypto,
  }) {
    if (databasePath != ':memory:') {
      Directory(path.dirname(databasePath)).createSync(recursive: true);
    }
    return SqliteProductivityRepository._(sqlite3.open(databasePath), crypto);
  }

  @override
  Future<ProductivitySnapshot> load() async {
    final noteRows = _database.select(
      'SELECT nonce, ciphertext FROM quick_note WHERE singleton = 1',
    );
    final timerRows = _database.select('''
      SELECT duration_seconds, remaining_seconds, end_at, running
      FROM timer_state WHERE singleton = 1
    ''');
    if (timerRows.isEmpty) {
      return ProductivitySnapshot(noteText: _decryptNote(noteRows));
    }
    final timer = timerRows.single;
    final endAtMilliseconds = timer['end_at'] as int?;
    return ProductivitySnapshot(
      noteText: _decryptNote(noteRows),
      timerDurationSeconds: timer['duration_seconds'] as int,
      timerRemainingSeconds: timer['remaining_seconds'] as int,
      timerEndAt: endAtMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              endAtMilliseconds,
              isUtc: true,
            ),
      timerRunning: timer['running'] == 1,
    );
  }

  @override
  Future<void> saveNote(String text) async {
    final encrypted = _crypto.encrypt(_noteId, text);
    _database.execute(
      '''
        INSERT INTO quick_note (
          singleton, nonce, ciphertext, updated_at
        ) VALUES (1, ?, ?, ?)
        ON CONFLICT(singleton) DO UPDATE SET
          nonce = excluded.nonce,
          ciphertext = excluded.ciphertext,
          updated_at = excluded.updated_at
      ''',
      [
        encrypted.nonce,
        encrypted.ciphertext,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  String _decryptNote(ResultSet rows) {
    if (rows.isEmpty) return '';
    try {
      return _crypto.decrypt(
        _noteId,
        rows.single['nonce'] as Uint8List,
        rows.single['ciphertext'] as Uint8List,
      );
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> saveTimer({
    required int durationSeconds,
    required int remainingSeconds,
    required DateTime? endAt,
    required bool running,
  }) async {
    _database.execute(
      '''
        INSERT INTO timer_state (
          singleton, duration_seconds, remaining_seconds, end_at, running
        ) VALUES (1, ?, ?, ?, ?)
        ON CONFLICT(singleton) DO UPDATE SET
          duration_seconds = excluded.duration_seconds,
          remaining_seconds = excluded.remaining_seconds,
          end_at = excluded.end_at,
          running = excluded.running
      ''',
      [
        durationSeconds,
        remainingSeconds,
        endAt?.toUtc().millisecondsSinceEpoch,
        running ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> close() async => _database.close();
}
