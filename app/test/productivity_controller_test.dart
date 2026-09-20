import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/productivity/productivity_controller.dart';
import 'package:islanddesk/productivity/productivity_repository.dart';
import 'package:islanddesk/productivity/productivity_snapshot.dart';

void main() {
  test('restores a running timer and accounts for elapsed wall time', () async {
    var now = DateTime.utc(2026, 9, 20, 12);
    final repository = _MemoryProductivityRepository(
      ProductivitySnapshot(
        noteText: 'Persisted note',
        timerDurationSeconds: 300,
        timerRemainingSeconds: 180,
        timerEndAt: now.add(const Duration(seconds: 180)),
        timerRunning: true,
      ),
    );
    final controller = ProductivityController(
      repository: repository,
      now: () => now,
      tickInterval: const Duration(hours: 1),
    );

    await controller.start();
    expect(controller.noteText, 'Persisted note');
    expect(controller.timerRunning, isTrue);
    expect(controller.timerRemainingSeconds, 180);

    now = now.add(const Duration(seconds: 75));
    await controller.refreshTimer();
    expect(controller.timerRemainingSeconds, 105);

    await controller.toggleTimer();
    expect(controller.timerRunning, isFalse);
    expect(repository.lastTimer?.timerRemainingSeconds, 105);
    await controller.close();
  });

  test('finishes a timer after sleep instead of losing elapsed time', () async {
    var now = DateTime.utc(2026, 9, 20, 12);
    final repository = _MemoryProductivityRepository();
    final controller = ProductivityController(
      repository: repository,
      now: () => now,
      tickInterval: const Duration(hours: 1),
    );
    await controller.start();
    await controller.selectTimerDuration(300);
    await controller.toggleTimer();

    now = now.add(const Duration(minutes: 7));
    await controller.refreshTimer();

    expect(controller.timerRunning, isFalse);
    expect(controller.timerRemainingSeconds, 0);
    expect(repository.lastTimer?.timerRunning, isFalse);
    expect(repository.lastTimer?.timerRemainingSeconds, 0);
    await controller.close();
  });

  test('flushes a pending note when the controller closes', () async {
    final repository = _MemoryProductivityRepository();
    final controller = ProductivityController(
      repository: repository,
      noteSaveDelay: const Duration(hours: 1),
    );
    await controller.start();

    controller.updateNote('Remember this');
    await controller.close();

    expect(repository.noteText, 'Remember this');
    expect(repository.closed, isTrue);
  });
}

class _MemoryProductivityRepository implements ProductivityRepository {
  _MemoryProductivityRepository([
    this.snapshot = const ProductivitySnapshot(),
  ]);

  ProductivitySnapshot snapshot;
  String noteText = '';
  ProductivitySnapshot? lastTimer;
  bool closed = false;

  @override
  Future<ProductivitySnapshot> load() async => snapshot;

  @override
  Future<void> saveNote(String text) async => noteText = text;

  @override
  Future<void> saveTimer({
    required int durationSeconds,
    required int remainingSeconds,
    required DateTime? endAt,
    required bool running,
  }) async {
    lastTimer = ProductivitySnapshot(
      timerDurationSeconds: durationSeconds,
      timerRemainingSeconds: remainingSeconds,
      timerEndAt: endAt,
      timerRunning: running,
    );
  }

  @override
  Future<void> close() async => closed = true;
}
