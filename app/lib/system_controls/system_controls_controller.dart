import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:islanddesk/src/rust/api/system_controls.dart' as rust_controls;

abstract interface class SystemControlsGateway {
  bool get isSupported;

  Future<rust_controls.SystemControlsState> currentState();

  Future<rust_controls.SystemControlsState> setOutputVolume(int volumePercent);

  Future<rust_controls.SystemControlsState> setOutputMuted(bool muted);

  Future<rust_controls.SystemControlsState> setInputMuted(bool muted);

  Future<rust_controls.SystemControlsState> setKeepAwake(bool active);
}

class RustSystemControlsGateway implements SystemControlsGateway {
  const RustSystemControlsGateway();

  @override
  bool get isSupported => Platform.isWindows;

  @override
  Future<rust_controls.SystemControlsState> currentState() =>
      rust_controls.getSystemControlsState();

  @override
  Future<rust_controls.SystemControlsState> setInputMuted(bool muted) =>
      rust_controls.setInputMuted(muted: muted);

  @override
  Future<rust_controls.SystemControlsState> setKeepAwake(bool active) =>
      rust_controls.setKeepAwake(active: active);

  @override
  Future<rust_controls.SystemControlsState> setOutputMuted(bool muted) =>
      rust_controls.setOutputMuted(muted: muted);

  @override
  Future<rust_controls.SystemControlsState> setOutputVolume(
    int volumePercent,
  ) =>
      rust_controls.setOutputVolume(volumePercent: volumePercent);
}

class SystemControlsController extends ChangeNotifier {
  SystemControlsController({
    SystemControlsGateway? gateway,
    this.refreshInterval = const Duration(seconds: 2),
  }) : _gateway = gateway ?? const RustSystemControlsGateway();

  final SystemControlsGateway _gateway;
  final Duration refreshInterval;

  rust_controls.SystemControlsState? _state;
  Timer? _timer;
  Future<void> _pendingCommand = Future.value();
  bool _started = false;
  bool _refreshInProgress = false;
  bool _commandInProgress = false;
  String? _errorMessage;

  bool get isSupported => _gateway.isSupported;
  rust_controls.SystemControlsState? get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _commandInProgress;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!isSupported) return;
    await refresh();
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (!isSupported || _refreshInProgress || _commandInProgress) return;
    _refreshInProgress = true;
    try {
      _accept(await _gateway.currentState());
    } catch (error) {
      _acceptError(error);
    } finally {
      _refreshInProgress = false;
    }
  }

  void previewOutputVolume(int volumePercent) {
    final current = _state;
    if (current == null || !current.output.available) return;
    _state = rust_controls.SystemControlsState(
      output: rust_controls.AudioEndpointState(
        available: true,
        volumePercent: volumePercent.clamp(0, 100),
        muted: current.output.muted,
      ),
      input: current.input,
      keepAwake: current.keepAwake,
    );
    notifyListeners();
  }

  Future<void> setOutputVolume(int volumePercent) => _execute(
        () => _gateway.setOutputVolume(volumePercent.clamp(0, 100)),
      );

  Future<void> setOutputMuted(bool muted) =>
      _execute(() => _gateway.setOutputMuted(muted));

  Future<void> setInputMuted(bool muted) =>
      _execute(() => _gateway.setInputMuted(muted));

  Future<void> setKeepAwake(bool active) =>
      _execute(() => _gateway.setKeepAwake(active));

  Future<void> _execute(
    Future<rust_controls.SystemControlsState> Function() command,
  ) {
    _pendingCommand = _pendingCommand.then((_) async {
      _commandInProgress = true;
      notifyListeners();
      try {
        _accept(await command());
      } catch (error) {
        _acceptError(error);
      } finally {
        _commandInProgress = false;
        notifyListeners();
      }
    });
    return _pendingCommand;
  }

  void _accept(rust_controls.SystemControlsState next) {
    _state = next;
    _errorMessage = null;
    notifyListeners();
  }

  void _acceptError(Object error) {
    _errorMessage = error.toString();
    notifyListeners();
  }

  Future<void> close() async {
    _timer?.cancel();
    await _pendingCommand;
    if (_state?.keepAwake == true) {
      try {
        _state = await _gateway.setKeepAwake(false);
      } catch (_) {
        // Windows clears the per-process request when IslandDesk exits.
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
