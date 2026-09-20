import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/src/rust/api/system_controls.dart';
import 'package:islanddesk/system_controls/system_controls_controller.dart';

void main() {
  test('loads and updates native system controls', () async {
    final gateway = _FakeSystemControlsGateway();
    final controller = SystemControlsController(
      gateway: gateway,
      refreshInterval: const Duration(hours: 1),
    );

    await controller.start();
    expect(controller.state?.output.volumePercent, 35);

    controller.previewOutputVolume(64);
    expect(controller.state?.output.volumePercent, 64);
    await controller.setOutputVolume(64);
    expect(gateway.outputVolume, 64);

    await controller.setOutputMuted(true);
    await controller.setInputMuted(true);
    await controller.setKeepAwake(true);
    expect(controller.state?.output.muted, isTrue);
    expect(controller.state?.input.muted, isTrue);
    expect(controller.state?.keepAwake, isTrue);

    await controller.close();
    expect(gateway.keepAwake, isFalse);
    controller.dispose();
  });

  test('reports native failures without discarding the last state', () async {
    final gateway = _FakeSystemControlsGateway();
    final controller = SystemControlsController(
      gateway: gateway,
      refreshInterval: const Duration(hours: 1),
    );
    await controller.start();
    gateway.failCommands = true;

    await controller.setOutputMuted(true);

    expect(controller.errorMessage, contains('command failed'));
    expect(controller.state?.output.muted, isFalse);
    await controller.close();
    controller.dispose();
  });
}

class _FakeSystemControlsGateway implements SystemControlsGateway {
  int outputVolume = 35;
  bool outputMuted = false;
  bool inputMuted = false;
  bool keepAwake = false;
  bool failCommands = false;

  @override
  bool get isSupported => true;

  SystemControlsState get _state => SystemControlsState(
        output: AudioEndpointState(
          available: true,
          volumePercent: outputVolume,
          muted: outputMuted,
        ),
        input: AudioEndpointState(
          available: true,
          volumePercent: 82,
          muted: inputMuted,
        ),
        keepAwake: keepAwake,
      );

  void _checkFailure() {
    if (failCommands) throw StateError('command failed');
  }

  @override
  Future<SystemControlsState> currentState() async => _state;

  @override
  Future<SystemControlsState> setInputMuted(bool muted) async {
    _checkFailure();
    inputMuted = muted;
    return _state;
  }

  @override
  Future<SystemControlsState> setKeepAwake(bool active) async {
    _checkFailure();
    keepAwake = active;
    return _state;
  }

  @override
  Future<SystemControlsState> setOutputMuted(bool muted) async {
    _checkFailure();
    outputMuted = muted;
    return _state;
  }

  @override
  Future<SystemControlsState> setOutputVolume(int volumePercent) async {
    _checkFailure();
    outputVolume = volumePercent;
    return _state;
  }
}
