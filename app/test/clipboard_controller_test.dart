import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/clipboard/clipboard_controller.dart';
import 'package:islanddesk/clipboard/clipboard_gateway.dart';
import 'package:islanddesk/clipboard/clipboard_item.dart';
import 'package:islanddesk/clipboard/clipboard_preferences.dart';
import 'package:islanddesk/clipboard/clipboard_repository.dart';

void main() {
  test('captures unique text and preserves pinned items when clearing',
      () async {
    final gateway = _FakeClipboardGateway();
    final repository = _MemoryClipboardRepository();
    final controller = ClipboardController(
      enabled: true,
      gateway: gateway,
      repository: repository,
    );

    await controller.start();
    gateway.add('first');
    gateway.add('first');
    gateway.add('second');
    await _flushEvents();

    expect(controller.items.map((item) => item.text), ['second', 'first']);
    await controller.togglePinned(controller.items.last.id);
    await controller.clearUnpinned();

    expect(controller.items.single.text, 'first');
    expect(controller.items.single.pinned, isTrue);
    await controller.close();
    controller.dispose();
    await gateway.close();
  });

  test('truncates large clipboard text before persistence', () async {
    final gateway = _FakeClipboardGateway();
    final repository = _MemoryClipboardRepository();
    final controller = ClipboardController(
      enabled: true,
      maxTextLength: 5,
      gateway: gateway,
      repository: repository,
    );
    await controller.start();

    gateway.add('123456789');
    await _flushEvents();

    expect(controller.items.single.text, '12345');
    await controller.close();
    controller.dispose();
    await gateway.close();
  });

  test('persists pause and ignores sensitive application events', () async {
    final gateway = _FakeClipboardGateway();
    final repository = _MemoryClipboardRepository();
    final controller = ClipboardController(
      enabled: true,
      gateway: gateway,
      repository: repository,
    );
    await controller.start();

    await controller.setCapturePaused(true);
    gateway.add('paused value', sourceApplication: 'notepad.exe');
    await _flushEvents();
    expect(controller.items, isEmpty);

    await controller.setCapturePaused(false);
    gateway.add(
      'password manager value',
      sourceApplication: r'C:\Apps\Bitwarden.exe',
    );
    gateway.add('allowed value', sourceApplication: 'notepad.exe');
    await _flushEvents();

    expect(controller.items.single.text, 'allowed value');
    expect(repository.preferences.capturePaused, isFalse);
    expect(
        repository.preferences.excludedApplications, contains('bitwarden.exe'));
    await controller.close();
    controller.dispose();
    await gateway.close();
  });
}

Future<void> _flushEvents() async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeClipboardGateway implements ClipboardGateway {
  final _controller = StreamController<ClipboardEvent>.broadcast(sync: true);

  @override
  bool get isSupported => true;

  void add(String text, {String sourceApplication = 'test.exe'}) =>
      _controller.add(
        ClipboardEvent(
          text: text,
          sourceApplication: sourceApplication,
        ),
      );

  Future<void> close() => _controller.close();

  @override
  Stream<ClipboardEvent> watchText() => _controller.stream;
}

class _MemoryClipboardRepository implements ClipboardRepository {
  final items = <ClipboardItem>[];
  ClipboardPreferences preferences = const ClipboardPreferences();

  @override
  Future<List<ClipboardItem>> load() async => List.of(items);

  @override
  Future<ClipboardPreferences> loadPreferences() async => preferences;

  @override
  Future<void> save(ClipboardItem item) async => items.add(item);

  @override
  Future<void> setPinned(String id, bool pinned) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(pinned: pinned);
  }

  @override
  Future<void> remove(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> clearUnpinned() async {
    items.removeWhere((item) => !item.pinned);
  }

  @override
  Future<void> savePreferences(ClipboardPreferences value) async {
    preferences = value;
  }

  @override
  Future<void> close() async {}
}
