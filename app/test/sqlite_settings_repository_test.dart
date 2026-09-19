import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/sqlite_settings_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

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
    expect(defaults.hideInFullscreen, isTrue);
    expect(defaults.autoHidePanel, isTrue);
    expect(defaults.monitorPreference, MonitorPreference.primary);
    expect(defaults.fixedMonitorId, isNull);

    await repository.save(
      const AppSettings(
        alwaysOnTop: false,
        animationsEnabled: false,
        hideInFullscreen: false,
        autoHidePanel: false,
        monitorPreference: MonitorPreference.fixed,
        fixedMonitorId: 'display-2',
      ),
    );

    await repository.close();
    repository = SqliteSettingsRepository.openAtPath(databasePath);

    final stored = await repository.load();
    expect(stored.alwaysOnTop, isFalse);
    expect(stored.animationsEnabled, isFalse);
    expect(stored.hideInFullscreen, isFalse);
    expect(stored.autoHidePanel, isFalse);
    expect(stored.monitorPreference, MonitorPreference.fixed);
    expect(stored.fixedMonitorId, 'display-2');

    await repository.close();
  });

  test('migrates a version 1 database without losing preferences', () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('islanddesk-settings-v1-');
    addTearDown(() => tempDirectory.delete(recursive: true));
    final databasePath = path.join(tempDirectory.path, 'settings.sqlite3');
    final database = sqlite3.open(databasePath);
    database.execute('''
      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value INTEGER NOT NULL CHECK (value IN (0, 1))
      ) STRICT
    ''');
    database.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?)',
      ['always_on_top', 0],
    );
    database.execute('PRAGMA user_version = 1');
    database.close();

    final repository = SqliteSettingsRepository.openAtPath(databasePath);
    final migrated = await repository.load();

    expect(migrated.alwaysOnTop, isFalse);
    expect(migrated.animationsEnabled, isTrue);
    expect(migrated.hideInFullscreen, isTrue);
    expect(migrated.autoHidePanel, isTrue);
    expect(migrated.monitorPreference, MonitorPreference.primary);
    await repository.close();
  });
}
