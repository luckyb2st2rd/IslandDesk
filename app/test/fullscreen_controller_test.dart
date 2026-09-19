import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/fullscreen_controller.dart';

void main() {
  test('tracks foreground fullscreen changes', () async {
    final gateway = _FakeFullscreenGateway();
    final controller = FullscreenController(
      gateway: gateway,
      refreshInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();
    expect(controller.isForegroundFullscreen, isFalse);

    gateway.value = true;
    await controller.refresh();

    expect(controller.isForegroundFullscreen, isTrue);
    expect(gateway.calls, 2);
  });

  test('keeps detection failures non-fatal', () async {
    final controller = FullscreenController(
      gateway: _FailingFullscreenGateway(),
      refreshInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.isForegroundFullscreen, isFalse);
    expect(controller.errorMessage, contains('unavailable'));
  });
}

class _FakeFullscreenGateway implements FullscreenGateway {
  bool value = false;
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isForegroundFullscreen() async {
    calls++;
    return value;
  }
}

class _FailingFullscreenGateway implements FullscreenGateway {
  @override
  bool get isSupported => true;

  @override
  Future<bool> isForegroundFullscreen() =>
      Future.error(StateError('fullscreen service unavailable'));
}
