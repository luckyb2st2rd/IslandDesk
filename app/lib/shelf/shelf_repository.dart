import 'package:islanddesk/shelf/shelf_item.dart';

abstract interface class ShelfRepository {
  Future<List<ShelfItem>> load();

  Future<void> save(ShelfItem item);

  Future<void> setPinned(String id, bool pinned);

  Future<void> remove(String id);

  Future<void> close();
}
