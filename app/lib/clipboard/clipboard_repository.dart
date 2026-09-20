import 'package:islanddesk/clipboard/clipboard_item.dart';
import 'package:islanddesk/clipboard/clipboard_preferences.dart';

abstract interface class ClipboardRepository {
  Future<List<ClipboardItem>> load();

  Future<ClipboardPreferences> loadPreferences();

  Future<void> save(ClipboardItem item);

  Future<void> setPinned(String id, bool pinned);

  Future<void> remove(String id);

  Future<void> clearUnpinned();

  Future<void> savePreferences(ClipboardPreferences preferences);

  Future<void> close();
}
