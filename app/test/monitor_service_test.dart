import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/src/rust/api/monitor.dart' as rust;
import 'package:screen_retriever/screen_retriever.dart';

void main() {
  const primary = Display(
    id: 'primary',
    name: 'Main',
    size: Size(1920, 1080),
    visiblePosition: Offset.zero,
    visibleSize: Size(1920, 1040),
    scaleFactor: 1.25,
  );
  const secondary = Display(
    id: 'secondary',
    name: 'Side',
    size: Size(2560, 1440),
    visiblePosition: Offset(1920, 0),
    visibleSize: Size(2560, 1400),
    scaleFactor: 1.5,
  );

  test('passes the monitor under the cursor to the Rust policy', () async {
    rust.MonitorMode? receivedMode;
    String? receivedActiveId;
    final service = MonitorService(
      displaySource: _FakeDisplaySource(
        displays: const [primary, secondary],
        primary: primary,
        // The cursor is in the secondary taskbar, just outside its work area.
        cursor: const Offset(2200, 1420),
      ),
      resolver: ({
        required mode,
        required displayIds,
        required primaryId,
        activeId,
        fixedId,
      }) {
        receivedMode = mode;
        receivedActiveId = activeId;
        return const rust.MonitorResolution(
          displayId: 'secondary',
          usedFallback: false,
        );
      },
    );

    final result = await service.resolve(
      mode: MonitorPreference.followActive,
    );

    expect(receivedMode, rust.MonitorMode.followActive);
    expect(receivedActiveId, 'secondary');
    expect(result?.display.id, 'secondary');
    expect(result?.usedFallback, isFalse);
  });

  test('describes available monitors with logical size and scale', () async {
    final service = MonitorService(
      displaySource: _FakeDisplaySource(
        displays: const [primary, secondary],
        primary: primary,
        cursor: Offset.zero,
      ),
    );

    final monitors = await service.listAvailableMonitors();

    expect(monitors, hasLength(2));
    expect(monitors.first.label, 'Main • 1920×1080 • 125% • Primary');
    expect(monitors.last.label, 'Side • 2560×1440 • 150%');
  });

  test('calculates top-center position in logical coordinates', () {
    expect(
      MonitorService.topCenterPosition(
        secondary,
        const Size(468, 224),
      ),
      const Offset(2966, 0),
    );
  });
}

class _FakeDisplaySource implements MonitorDisplaySource {
  const _FakeDisplaySource({
    required this.displays,
    required this.primary,
    required this.cursor,
  });

  final List<Display> displays;
  final Display primary;
  final Offset cursor;

  @override
  Future<List<Display>> getAllDisplays() async => displays;

  @override
  Future<Offset> getCursorScreenPoint() async => cursor;

  @override
  Future<Display> getPrimaryDisplay() async => primary;
}
