import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/desktop/monitor_service.dart';
import 'package:islanddesk/island/island_state.dart';
import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/settings/settings_repository.dart';

void main() {
  test('forwards island changes and switches application views', () {
    final controller = ApplicationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.island.toggleExpanded();
    expect(controller.island.state, IslandState.expanded);
    expect(notifications, 1);

    controller.showSettings();
    expect(controller.view, ApplicationView.settings);
    expect(notifications, 2);

    controller.showIsland();
    expect(controller.view, ApplicationView.island);
    expect(controller.island.state, IslandState.collapsed);

    controller.dispose();
  });

  test('updates session settings', () {
    final controller = ApplicationController();

    controller.setAlwaysOnTop(false);
    controller.setAnimationsEnabled(false);
    controller.setHideInFullscreen(false);
    controller.setMonitorPreference(MonitorPreference.followActive);

    expect(controller.alwaysOnTop, isFalse);
    expect(controller.animationsEnabled, isFalse);
    expect(controller.hideInFullscreen, isFalse);
    expect(controller.monitorPreference, MonitorPreference.followActive);

    controller.dispose();
  });

  test('suppresses only the island view when fullscreen hiding is enabled', () {
    final controller = ApplicationController();

    expect(controller.shouldSuppressForFullscreen(true), isTrue);
    expect(controller.shouldSuppressForFullscreen(false), isFalse);

    controller.showSettings();
    expect(controller.shouldSuppressForFullscreen(true), isFalse);

    controller.setHideInFullscreen(false);
    controller.showIsland();
    expect(controller.shouldSuppressForFullscreen(true), isFalse);
    controller.dispose();
  });

  test('chooses an available display when fixed mode is selected', () {
    final controller = ApplicationController(
      availableMonitors: const [
        MonitorOption(id: 'display-2', label: 'Display 2'),
      ],
    );

    controller.setMonitorPreference(MonitorPreference.fixed);

    expect(controller.monitorPreference, MonitorPreference.fixed);
    expect(controller.fixedMonitorId, 'display-2');
    controller.dispose();
  });

  test('flushes pending settings before closing', () async {
    final repository = _FakeSettingsRepository();
    final controller = ApplicationController(settingsRepository: repository);

    controller.setAlwaysOnTop(false);
    controller.setAnimationsEnabled(false);
    controller.setHideInFullscreen(false);
    controller.setMonitorPreference(MonitorPreference.followActive);
    await controller.close();

    expect(repository.saved?.alwaysOnTop, isFalse);
    expect(repository.saved?.animationsEnabled, isFalse);
    expect(repository.saved?.hideInFullscreen, isFalse);
    expect(
      repository.saved?.monitorPreference,
      MonitorPreference.followActive,
    );
    expect(repository.isClosed, isTrue);

    controller.dispose();
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings? saved;
  bool isClosed = false;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    saved = settings;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}
