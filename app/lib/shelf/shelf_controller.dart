import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/shelf/shelf_item.dart';
import 'package:islanddesk/shelf/shelf_repository.dart';
import 'package:path/path.dart' as path;

class ShelfController extends ChangeNotifier {
  ShelfController({ShelfRepository? repository}) : _repository = repository;

  final ShelfRepository? _repository;
  final List<ShelfItem> _items = [];
  final Set<String> _pendingPaths = {};
  String? _errorMessage;

  List<ShelfItem> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      _items
        ..clear()
        ..addAll(await repository.load());
      _sort();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'File Shelf could not be loaded';
    }
    notifyListeners();
  }

  Future<int> addPaths(Iterable<String> paths) async {
    var added = 0;
    _errorMessage = null;
    for (final rawPath in paths) {
      try {
        final normalized = path.normalize(path.absolute(rawPath));
        final pathKey = _pathKey(normalized);
        if (_containsPath(normalized) || !_pendingPaths.add(pathKey)) continue;
        try {
          final file = File(normalized);
          final stat = await file.stat();
          if (stat.type != FileSystemEntityType.file) continue;
          final now = DateTime.now().toUtc();
          final item = ShelfItem(
            id: '${now.microsecondsSinceEpoch}-$added',
            filePath: normalized,
            filename: path.basename(normalized),
            extension: path.extension(normalized).replaceFirst('.', ''),
            fileSize: stat.size,
            createdAt: now,
            pinned: false,
          );
          await _repository?.save(item);
          _items.add(item);
          added++;
        } finally {
          _pendingPaths.remove(pathKey);
        }
      } catch (_) {
        _errorMessage = 'Some dropped files could not be added';
      }
    }
    if (added > 0 || _errorMessage != null) {
      _sort();
      notifyListeners();
    }
    return added;
  }

  Future<void> togglePinned(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final updated = _items[index].copyWith(pinned: !_items[index].pinned);
    try {
      await _repository?.setPinned(id, updated.pinned);
      _items[index] = updated;
      _sort();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'The pinned state could not be saved';
    }
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    try {
      await _repository?.remove(id);
      _items.removeAt(index);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'The shelf item could not be removed';
    }
    notifyListeners();
  }

  bool _containsPath(String candidate) {
    final comparable = _pathKey(candidate);
    return _items.any((item) {
      return _pathKey(item.filePath) == comparable;
    });
  }

  String _pathKey(String value) =>
      Platform.isWindows ? value.toLowerCase() : value;

  void _sort() {
    _items.sort((left, right) {
      if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
      return right.createdAt.compareTo(left.createdAt);
    });
  }

  Future<void> close() async => _repository?.close();
}
