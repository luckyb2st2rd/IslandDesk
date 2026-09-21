import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/global_hotkey_controller.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/src/rust/api/hotkey.dart';

void main() {
  test('registers, reconfigures and forwards activations', () async {
    final gateway = _FakeHotkeyGateway();
    var activations = 0;
    final controller = GlobalHotkeyController(
      gateway: gateway,
      onActivated: () => activations++,
    );

    await controller.start(GlobalHotkeyShortcut.ctrlAltSpace);
    gateway.emit(
      const GlobalHotkeyEvent(activated: false, registered: true),
    );
    expect(controller.registered, isTrue);
    expect(gateway.configured, GlobalHotkeyShortcut.ctrlAltSpace);

    gateway.emit(
      const GlobalHotkeyEvent(activated: true, registered: true),
    );
    expect(activations, 1);

    controller.configure(GlobalHotkeyShortcut.ctrlAltI);
    expect(gateway.configured, GlobalHotkeyShortcut.ctrlAltI);

    await controller.close();
    controller.dispose();
    await gateway.close();
  });

  test('reports registration conflicts without activating', () async {
    final gateway = _FakeHotkeyGateway();
    final controller = GlobalHotkeyController(
      gateway: gateway,
      onActivated: () => fail('must not activate'),
    );

    await controller.start(GlobalHotkeyShortcut.ctrlShiftSpace);
    gateway.emit(
      const GlobalHotkeyEvent(
        activated: false,
        registered: false,
        errorCode: 'hotkey_unavailable',
      ),
    );

    expect(controller.registered, isFalse);
    expect(controller.errorCode, 'hotkey_unavailable');
    controller.dispose();
    await gateway.close();
  });
}

class _FakeHotkeyGateway implements GlobalHotkeyGateway {
  final _events = StreamController<GlobalHotkeyEvent>.broadcast(sync: true);
  GlobalHotkeyShortcut? configured;

  @override
  bool get isSupported => true;

  @override
  void configure(GlobalHotkeyShortcut shortcut) => configured = shortcut;

  @override
  Stream<GlobalHotkeyEvent> watch() => _events.stream;

  void emit(GlobalHotkeyEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}
