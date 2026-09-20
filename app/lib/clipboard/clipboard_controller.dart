import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/clipboard/clipboard_gateway.dart';
import 'package:islanddesk/clipboard/clipboard_item.dart';
import 'package:islanddesk/clipboard/clipboard_preferences.dart';
import 'package:islanddesk/clipboard/clipboard_repository.dart';

class ClipboardController extends ChangeNotifier {
  ClipboardController({
    ClipboardGateway? gateway,
    ClipboardRepository? repository,
    this.enabled = false,
    this.maxTextLength = 20000,
    this.maxUnpinnedItems = 50,
  })  : _gateway = gateway ?? const RustClipboardGateway(),
        _repository = repository;

  final ClipboardGateway _gateway;
  final ClipboardRepository? _repository;
  final bool enabled;
  final int maxTextLength;
  final int maxUnpinnedItems;
  final List<ClipboardItem> _items = [];
  StreamSubscription<ClipboardEvent>? _subscription;
  Future<void> _pendingWrite = Future.value();
  String? _errorMessage;
  bool _started = false;
  int _idSequence = 0;
  ClipboardPreferences _preferences = const ClipboardPreferences();

  List<ClipboardItem> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;
  bool get capturePaused => _preferences.capturePaused;
  List<String> get excludedApplications =>
      List.unmodifiable(_preferences.excludedApplications);
  bool get isListening =>
      enabled && _subscription != null && _gateway.isSupported;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _items
        ..clear()
        ..addAll(await _repository?.load() ?? const []);
      _preferences =
          await _repository?.loadPreferences() ?? const ClipboardPreferences();
      _preferences = _preferences.copyWith(
        excludedApplications: _normalizedApplications(
          _preferences.excludedApplications,
        ),
      );
      _sort();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Clipboard history could not be decrypted';
    }
    notifyListeners();
    if (!enabled || !_gateway.isSupported) return;
    _subscription = _gateway.watchText().listen(
      _queueText,
      onError: (_) {
        _errorMessage = 'Windows clipboard listener stopped';
        notifyListeners();
      },
    );
  }

  void _queueText(ClipboardEvent event) {
    _pendingWrite = _pendingWrite.then((_) => _acceptEvent(event));
  }

  Future<void> _acceptEvent(ClipboardEvent event) async {
    if (event.isHeartbeat ||
        capturePaused ||
        _isExcluded(event.sourceApplication)) {
      return;
    }
    final text = event.text;
    if (text == null || text.trim().isEmpty) return;
    final safeText =
        text.length > maxTextLength ? text.substring(0, maxTextLength) : text;
    if (_items.isNotEmpty && _items.first.text == safeText) return;
    final now = DateTime.now().toUtc();
    final item = ClipboardItem(
      id: '${now.microsecondsSinceEpoch}-${_idSequence++}',
      text: safeText,
      createdAt: now,
      pinned: false,
    );
    try {
      await _repository?.save(item);
      _items.insert(0, item);
      _trimInMemory();
      _errorMessage = null;
      _sort();
    } catch (_) {
      _errorMessage = 'Clipboard item could not be encrypted';
    }
    notifyListeners();
  }

  Future<void> setCapturePaused(bool paused) async {
    if (_preferences.capturePaused == paused) return;
    final updated = _preferences.copyWith(capturePaused: paused);
    try {
      await _repository?.savePreferences(updated);
      _preferences = updated;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Clipboard pause state could not be saved';
    }
    notifyListeners();
  }

  Future<void> setExcludedApplications(Iterable<String> applications) async {
    final updated = _preferences.copyWith(
      excludedApplications: _normalizedApplications(applications),
    );
    try {
      await _repository?.savePreferences(updated);
      _preferences = updated;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Sensitive application exclusions could not be saved';
    }
    notifyListeners();
  }

  bool _isExcluded(String application) {
    final key = _applicationKey(application);
    return key.isNotEmpty &&
        _preferences.excludedApplications.any(
          (excluded) => _applicationKey(excluded) == key,
        );
  }

  Future<void> togglePinned(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final updated = _items[index].copyWith(pinned: !_items[index].pinned);
    try {
      await _repository?.setPinned(id, updated.pinned);
      _items[index] = updated;
      _errorMessage = null;
      _sort();
    } catch (_) {
      _errorMessage = 'Clipboard pin could not be saved';
    }
    notifyListeners();
  }

  Future<void> remove(String id) async {
    try {
      await _repository?.remove(id);
      _items.removeWhere((item) => item.id == id);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Clipboard item could not be removed';
    }
    notifyListeners();
  }

  Future<void> clearUnpinned() async {
    try {
      await _repository?.clearUnpinned();
      _items.removeWhere((item) => !item.pinned);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Clipboard history could not be cleared';
    }
    notifyListeners();
  }

  void _sort() {
    _items.sort((left, right) {
      if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
      return right.createdAt.compareTo(left.createdAt);
    });
  }

  void _trimInMemory() {
    var unpinnedCount = 0;
    _items.removeWhere((item) {
      if (item.pinned) return false;
      unpinnedCount++;
      return unpinnedCount > maxUnpinnedItems;
    });
  }

  static List<String> _normalizedApplications(Iterable<String> applications) {
    final values = applications
        .map((application) => application.trim().replaceAll('\\', '/'))
        .map((application) => application.split('/').last.toLowerCase())
        .where((application) => application.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  static String _applicationKey(String application) {
    final normalized =
        application.trim().replaceAll('\\', '/').split('/').last.toLowerCase();
    return normalized.endsWith('.exe')
        ? normalized.substring(0, normalized.length - 4)
        : normalized;
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _pendingWrite;
    await _repository?.close();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
