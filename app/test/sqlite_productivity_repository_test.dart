import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/productivity/sqlite_productivity_repository.dart';
import 'package:islanddesk/src/rust/api/clipboard.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('persists quick note and timer state', () async {
    final directory =
        await Directory.systemTemp.createTemp('islanddesk_productivity_');
    final databasePath = '${directory.path}/productivity.sqlite3';
    final repository = SqliteProductivityRepository.openAtPath(
      databasePath,
      crypto: const _TestProductivityCrypto(),
    );
    final endAt = DateTime.utc(2026, 9, 20, 14, 30);

    await repository.saveNote('Ship IslandDesk');
    await repository.saveTimer(
      durationSeconds: 600,
      remainingSeconds: 425,
      endAt: endAt,
      running: true,
    );

    final loaded = await repository.load();
    expect(loaded.noteText, 'Ship IslandDesk');
    expect(loaded.timerDurationSeconds, 600);
    expect(loaded.timerRemainingSeconds, 425);
    expect(loaded.timerEndAt, endAt);
    expect(loaded.timerRunning, isTrue);
    await repository.close();

    final rawDatabase = sqlite3.open(databasePath);
    final row = rawDatabase
        .select(
          'SELECT nonce, ciphertext FROM quick_note WHERE singleton = 1',
        )
        .single;
    expect(row['nonce'] as Uint8List, hasLength(12));
    expect(
      row['ciphertext'] as Uint8List,
      isNot(equals(utf8.encode('Ship IslandDesk'))),
    );
    rawDatabase.close();
    await directory.delete(recursive: true);
  });
}

class _TestProductivityCrypto implements ProductivityCrypto {
  const _TestProductivityCrypto();

  static const _mask = 0x5A;

  @override
  ClipboardEncryptedData encrypt(String id, String text) =>
      ClipboardEncryptedData(
        nonce: Uint8List.fromList(List<int>.filled(12, id.length)),
        ciphertext: Uint8List.fromList(
          utf8.encode('$id\u0000$text').map((byte) => byte ^ _mask).toList(),
        ),
      );

  @override
  String decrypt(String id, Uint8List nonce, Uint8List ciphertext) {
    final value = utf8.decode(
      ciphertext.map((byte) => byte ^ _mask).toList(),
    );
    final prefix = '$id\u0000';
    if (!value.startsWith(prefix)) throw StateError('Authentication failed');
    return value.substring(prefix.length);
  }
}
