import 'package:islanddesk/productivity/productivity_snapshot.dart';

abstract interface class ProductivityRepository {
  Future<ProductivitySnapshot> load();

  Future<void> saveNote(String text);

  Future<void> saveTimer({
    required int durationSeconds,
    required int remainingSeconds,
    required DateTime? endAt,
    required bool running,
  });

  Future<void> close();
}
