import 'package:islanddesk/launcher/launcher_item.dart';

abstract interface class LauncherRepository {
  Future<List<LauncherItem>> load();

  Future<void> save(LauncherItem item);

  Future<void> reorder(List<String> ids);

  Future<void> remove(String id);

  Future<void> close();
}
