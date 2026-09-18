import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/sqlite_settings_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  test('uses defaults and persists settings', () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('islanddesk-settings-');
    addTearDown(() => tempDirectory.delete(recursive: true));
    final databasePath = path.join(tempDirectory.path, 'settings.sqlite3');
    var repository = SqliteSettingsRepository.openAtPath(databasePath);

    final defaults = await repository.load();
    expect(defaults.alwaysOnTop, isTrue);
    expect(defaults.animationsEnabled, isTrue);

    await repository.save(
      const AppSettings(alwaysOnTop: false, animationsEnabled: false),
    );

    await repository.close();
    repository = SqliteSettingsRepository.openAtPath(databasePath);

    final stored = await repository.load();
    expect(stored.alwaysOnTop, isFalse);
    expect(stored.animationsEnabled, isFalse);

    await repository.close();
  });
}
