import 'dart:io';

import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/settings_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository._(this._database) {
    _migrate();
  }

  static const _schemaVersion = 2;
  static const _inMemoryDatabasePath = ':memory:';
  static const _alwaysOnTopKey = 'always_on_top';
  static const _animationsEnabledKey = 'animations_enabled';
  static const _hideInFullscreenKey = 'hide_in_fullscreen';
  static const _monitorPreferenceKey = 'monitor_preference';
  static const _fixedMonitorIdKey = 'fixed_monitor_id';

  final Database _database;

  static Future<SqliteSettingsRepository> open() async {
    final supportDirectory = await getApplicationSupportDirectory();
    await supportDirectory.create(recursive: true);
    return openAtPath(path.join(supportDirectory.path, 'islanddesk.sqlite3'));
  }

  static SqliteSettingsRepository openAtPath(String databasePath) {
    if (databasePath != _inMemoryDatabasePath) {
      Directory(path.dirname(databasePath)).createSync(recursive: true);
    }
    return SqliteSettingsRepository._(sqlite3.open(databasePath));
  }

  void _migrate() {
    final currentVersion =
        _database.select('PRAGMA user_version').single.columnAt(0) as int;
    if (currentVersion >= _schemaVersion) return;

    _database.execute('BEGIN IMMEDIATE');
    try {
      if (currentVersion < 1) {
        _database.execute('''
          CREATE TABLE settings (
            key TEXT NOT NULL PRIMARY KEY,
            value INTEGER NOT NULL CHECK (value IN (0, 1))
          ) STRICT
        ''');
      }
      if (currentVersion < 2) {
        _database.execute('''
          CREATE TABLE text_settings (
            key TEXT NOT NULL PRIMARY KEY,
            value TEXT NOT NULL
          ) STRICT
        ''');
      }
      _database.execute('PRAGMA user_version = $_schemaVersion');
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<AppSettings> load() async {
    return AppSettings(
      alwaysOnTop: _readBool(_alwaysOnTopKey, fallback: true),
      animationsEnabled: _readBool(_animationsEnabledKey, fallback: true),
      hideInFullscreen: _readBool(_hideInFullscreenKey, fallback: true),
      monitorPreference: MonitorPreference.fromStorage(
        _readText(_monitorPreferenceKey),
      ),
      fixedMonitorId: _readText(_fixedMonitorIdKey),
    );
  }

  String? _readText(String key) {
    final rows = _database.select(
      'SELECT value FROM text_settings WHERE key = ?',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.single['value'] as String;
  }

  bool _readBool(String key, {required bool fallback}) {
    final rows = _database.select(
      'SELECT value FROM settings WHERE key = ?',
      [key],
    );
    if (rows.isEmpty) return fallback;
    return rows.single['value'] == 1;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _database.execute('BEGIN IMMEDIATE');
    try {
      _writeBool(_alwaysOnTopKey, settings.alwaysOnTop);
      _writeBool(_animationsEnabledKey, settings.animationsEnabled);
      _writeBool(_hideInFullscreenKey, settings.hideInFullscreen);
      _writeText(
        _monitorPreferenceKey,
        settings.monitorPreference.storageValue,
      );
      _writeOptionalText(_fixedMonitorIdKey, settings.fixedMonitorId);
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _writeText(String key, String value) {
    _database.execute(
      '''
        INSERT INTO text_settings (key, value) VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }

  void _writeOptionalText(String key, String? value) {
    if (value == null) {
      _database.execute('DELETE FROM text_settings WHERE key = ?', [key]);
      return;
    }
    _writeText(key, value);
  }

  void _writeBool(String key, bool value) {
    _database.execute(
      '''
        INSERT INTO settings (key, value) VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value ? 1 : 0],
    );
  }

  @override
  Future<void> close() async => _database.close();
}
