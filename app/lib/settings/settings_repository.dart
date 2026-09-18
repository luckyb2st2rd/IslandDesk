import 'package:islanddesk/settings/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);

  Future<void> close();
}
