import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/shelf/shelf_controller.dart';
import 'package:islanddesk/shelf/shelf_item.dart';
import 'package:islanddesk/shelf/shelf_repository.dart';

void main() {
  test('adds files once, pins them and removes only shelf metadata', () async {
    final directory = await Directory.systemTemp.createTemp('islanddesk-shelf');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}sample.txt');
    await file.writeAsString('IslandDesk');
    final repository = _MemoryShelfRepository();
    final controller = ShelfController(repository: repository);

    final additions = await Future.wait([
      controller.addPaths([file.path]),
      controller.addPaths([file.path, directory.path]),
    ]);

    expect(additions.reduce((left, right) => left + right), 1);
    expect(controller.items, hasLength(1));
    expect(controller.items.single.filename, 'sample.txt');
    expect(controller.items.single.extension, 'txt');
    expect(controller.items.single.fileSize, 10);

    final id = controller.items.single.id;
    await controller.togglePinned(id);
    expect(controller.items.single.pinned, isTrue);
    expect(repository.items.single.pinned, isTrue);

    await controller.remove(id);
    expect(controller.items, isEmpty);
    expect(await file.exists(), isTrue);
    controller.dispose();
  });

  test('loads pinned items before recent unpinned items', () async {
    final repository = _MemoryShelfRepository()
      ..items.addAll([
        _item('recent', DateTime.utc(2026, 1, 2)),
        _item('pinned', DateTime.utc(2026, 1, 1), pinned: true),
      ]);
    final controller = ShelfController(repository: repository);

    await controller.load();

    expect(controller.items.map((item) => item.id), ['pinned', 'recent']);
    controller.dispose();
  });

  test('marks deleted files missing and relinks a replacement', () async {
    final directory = await Directory.systemTemp.createTemp('islanddesk-shelf');
    addTearDown(() => directory.delete(recursive: true));
    final original = File('${directory.path}${Platform.pathSeparator}old.txt');
    final replacement =
        File('${directory.path}${Platform.pathSeparator}replacement.md');
    await original.writeAsString('old');
    await replacement.writeAsString('replacement');
    final repository = _MemoryShelfRepository();
    final controller = ShelfController(repository: repository);
    await controller.addPaths([original.path]);
    final id = controller.items.single.id;

    await original.delete();
    await controller.refreshAvailability();
    expect(controller.items.single.isMissing, isTrue);

    expect(await controller.relink(id, replacement.path), isTrue);
    expect(controller.items.single.isMissing, isFalse);
    expect(controller.items.single.filename, 'replacement.md');
    expect(controller.items.single.extension, 'md');
    expect(controller.items.single.fileSize, 11);
    expect(repository.items.single.filePath, replacement.path);
    controller.dispose();
  });
}

ShelfItem _item(String id, DateTime createdAt, {bool pinned = false}) {
  return ShelfItem(
    id: id,
    filePath: 'C:/$id.txt',
    filename: '$id.txt',
    extension: 'txt',
    fileSize: 10,
    createdAt: createdAt,
    pinned: pinned,
  );
}

class _MemoryShelfRepository implements ShelfRepository {
  final List<ShelfItem> items = [];

  @override
  Future<List<ShelfItem>> load() async => List.of(items);

  @override
  Future<void> save(ShelfItem item) async => items.add(item);

  @override
  Future<void> setPinned(String id, bool pinned) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(pinned: pinned);
  }

  @override
  Future<void> replaceFile(ShelfItem item) async {
    final index = items.indexWhere((existing) => existing.id == item.id);
    items[index] = item;
  }

  @override
  Future<void> remove(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> close() async {}
}
