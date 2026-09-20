import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/launcher/launcher_item.dart';
import 'package:islanddesk/launcher/launcher_repository.dart';
import 'package:islanddesk/src/rust/api/launcher.dart' as rust_launcher;
import 'package:path/path.dart' as path;

abstract interface class LauncherGateway {
  bool get isSupported;

  Future<bool> launch(LauncherItem item);
}

class RustLauncherGateway implements LauncherGateway {
  const RustLauncherGateway();

  @override
  bool get isSupported => Platform.isWindows;

  @override
  Future<bool> launch(LauncherItem item) => rust_launcher.launchApplication(
        executablePath: item.executablePath,
        arguments: item.arguments,
        workingDirectory: item.workingDirectory,
      );
}

class LauncherController extends ChangeNotifier {
  LauncherController({
    LauncherRepository? repository,
    LauncherGateway? gateway,
  })  : _repository = repository,
        _gateway = gateway ?? const RustLauncherGateway();

  static const supportedWindowsExtensions = {
    '.exe',
    '.lnk',
    '.com',
    '.bat',
    '.cmd',
  };

  final LauncherRepository? _repository;
  final LauncherGateway _gateway;
  final List<LauncherItem> _items = [];
  String? _errorMessage;
  int _idSequence = 0;

  List<LauncherItem> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;
  bool get isSupported => _gateway.isSupported;

  Future<void> load() async {
    try {
      _items
        ..clear()
        ..addAll(await _repository?.load() ?? const []);
      await refreshAvailability(notify: false);
      _normalizePositions();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Saved applications could not be loaded';
    }
    notifyListeners();
  }

  Future<bool> addPath(String rawPath) async {
    try {
      final normalized = path.normalize(path.absolute(rawPath));
      if (_containsPath(normalized)) return false;
      final extension = path.extension(normalized).toLowerCase();
      if (Platform.isWindows &&
          !supportedWindowsExtensions.contains(extension)) {
        _errorMessage = 'Choose an executable or Windows shortcut';
        notifyListeners();
        return false;
      }
      if (!await File(normalized).exists()) {
        _errorMessage = 'The selected application no longer exists';
        notifyListeners();
        return false;
      }
      final now = DateTime.now().toUtc();
      final item = LauncherItem(
        id: '${now.microsecondsSinceEpoch}-${_idSequence++}',
        executablePath: normalized,
        displayName: _displayName(normalized),
        workingDirectory: path.dirname(normalized),
        position: _items.length,
        createdAt: now,
      );
      await _repository?.save(item);
      _items.add(item);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'The application could not be added';
      notifyListeners();
      return false;
    }
  }

  Future<bool> launch(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || !_gateway.isSupported) return false;
    final item = _items[index];
    if (!await File(item.executablePath).exists()) {
      _items[index] = item.copyWith(isMissing: true);
      _errorMessage = 'The application has moved or was removed';
      notifyListeners();
      return false;
    }
    try {
      final launched = await _gateway.launch(item);
      _errorMessage = launched ? null : 'Windows rejected the launch request';
      notifyListeners();
      return launched;
    } catch (_) {
      _errorMessage = 'The application could not be launched';
      notifyListeners();
      return false;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    newIndex = newIndex.clamp(0, _items.length - 1);
    if (oldIndex == newIndex) return;
    final before = List<LauncherItem>.of(_items);
    final moved = _items.removeAt(oldIndex);
    _items.insert(newIndex, moved);
    _normalizePositions();
    notifyListeners();
    try {
      await _repository?.reorder(_items.map((item) => item.id).toList());
      _errorMessage = null;
    } catch (_) {
      _items
        ..clear()
        ..addAll(before);
      _errorMessage = 'The application order could not be saved';
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    try {
      await _repository?.remove(id);
      _items.removeAt(index);
      _normalizePositions();
      await _repository?.reorder(_items.map((item) => item.id).toList());
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'The application could not be removed';
    }
    notifyListeners();
  }

  Future<void> refreshAvailability({bool notify = true}) async {
    var changed = false;
    for (var index = 0; index < _items.length; index++) {
      final missing = !await File(_items[index].executablePath).exists();
      if (_items[index].isMissing != missing) {
        _items[index] = _items[index].copyWith(isMissing: missing);
        changed = true;
      }
    }
    if (changed && notify) notifyListeners();
  }

  void _normalizePositions() {
    for (var index = 0; index < _items.length; index++) {
      _items[index] = _items[index].copyWith(position: index);
    }
  }

  bool _containsPath(String candidate) {
    final key = _pathKey(candidate);
    return _items.any((item) => _pathKey(item.executablePath) == key);
  }

  String _pathKey(String value) =>
      Platform.isWindows ? value.toLowerCase() : value;

  static String _displayName(String executablePath) {
    final basename = path.basenameWithoutExtension(executablePath);
    return basename.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  Future<void> close() async => _repository?.close();
}
