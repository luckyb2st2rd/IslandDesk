import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/clipboard/clipboard_item.dart';
import 'package:islanddesk/clipboard/sqlite_clipboard_repository.dart';
import 'package:islanddesk/src/rust/api/clipboard.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('stores ciphertext and decrypts persisted clipboard history', () async {
    final directory =
        await Directory.systemTemp.createTemp('islanddesk_clipboard_');
    final databasePath = '${directory.path}/clipboard.sqlite3';
    final crypto = _TestClipboardCrypto();
    final repository = SqliteClipboardRepository.openAtPath(
      databasePath,
      crypto: crypto,
      maxUnpinnedItems: 2,
    );
    final first = _item('first', 'private clipboard text', 1);
    final second = _item('second', 'second text', 2);
    final third = _item('third', 'third text', 3);

    await repository.save(first);
    await repository.setPinned(first.id, true);
    await repository.save(second);
    await repository.save(third);
    await repository.close();

    final rawDatabase = sqlite3.open(databasePath);
    final rawRows = rawDatabase.select(
      'SELECT nonce, ciphertext FROM clipboard_items WHERE id = ?',
      [first.id],
    );
    expect(rawRows, hasLength(1));
    expect(
      rawRows.single['ciphertext'] as Uint8List,
      isNot(equals(utf8.encode(first.text))),
    );
    expect(rawRows.single['nonce'] as Uint8List, hasLength(12));
    rawDatabase.close();

    final reopened = SqliteClipboardRepository.openAtPath(
      databasePath,
      crypto: crypto,
      maxUnpinnedItems: 2,
    );
    final loaded = await reopened.load();
    expect(loaded.map((item) => item.text), [
      'private clipboard text',
      'third text',
      'second text',
    ]);
    expect(loaded.first.pinned, isTrue);
    await reopened.close();
    await directory.delete(recursive: true);
  });
}

ClipboardItem _item(String id, String text, int seconds) => ClipboardItem(
      id: id,
      text: text,
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, seconds),
      pinned: false,
    );

class _TestClipboardCrypto implements ClipboardCrypto {
  static const _mask = 0xA5;

  @override
  ClipboardEncryptedData encrypt(String id, String text) {
    final bytes = utf8.encode('$id\u0000$text');
    return ClipboardEncryptedData(
      nonce: Uint8List.fromList(List<int>.filled(12, id.length)),
      ciphertext: Uint8List.fromList(
        bytes.map((byte) => byte ^ _mask).toList(),
      ),
    );
  }

  @override
  String decrypt(String id, Uint8List nonce, Uint8List ciphertext) {
    final decoded =
        utf8.decode(ciphertext.map((byte) => byte ^ _mask).toList());
    final prefix = '$id\u0000';
    if (!decoded.startsWith(prefix)) throw StateError('authentication failed');
    return decoded.substring(prefix.length);
  }
}
