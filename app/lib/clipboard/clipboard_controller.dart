import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/clipboard/clipboard_gateway.dart';
import 'package:islanddesk/clipboard/clipboard_item.dart';
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
  StreamSubscription<String?>? _subscription;
  Future<void> _pendingWrite = Future.value();
  String? _errorMessage;
  bool _started = false;
  int _idSequence = 0;

  List<ClipboardItem> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;
  bool get isListening =>
      enabled && _subscription != null && _gateway.isSupported;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _items
        ..clear()
        ..addAll(await _repository?.load() ?? const []);
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

  void _queueText(String? text) {
    _pendingWrite = _pendingWrite.then((_) => _acceptText(text));
  }

  Future<void> _acceptText(String? text) async {
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
