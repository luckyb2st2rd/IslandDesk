import 'package:islanddesk/clipboard/clipboard_item.dart';

abstract interface class ClipboardRepository {
  Future<List<ClipboardItem>> load();

  Future<void> save(ClipboardItem item);

  Future<void> setPinned(String id, bool pinned);

  Future<void> remove(String id);

  Future<void> clearUnpinned();

  Future<void> close();
}
