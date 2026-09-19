import 'dart:ui';

import 'package:islanddesk/settings/app_settings.dart';
import 'package:islanddesk/src/rust/api/monitor.dart' as rust;
import 'package:screen_retriever/screen_retriever.dart';

class MonitorOption {
  const MonitorOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ResolvedMonitor {
  const ResolvedMonitor({
    required this.display,
    required this.usedFallback,
  });

  final Display display;
  final bool usedFallback;
}

abstract interface class MonitorDisplaySource {
  Future<List<Display>> getAllDisplays();

  Future<Display> getPrimaryDisplay();

  Future<Offset> getCursorScreenPoint();
}

class ScreenRetrieverDisplaySource implements MonitorDisplaySource {
  const ScreenRetrieverDisplaySource();

  @override
  Future<List<Display>> getAllDisplays() => screenRetriever.getAllDisplays();

  @override
  Future<Display> getPrimaryDisplay() => screenRetriever.getPrimaryDisplay();

  @override
  Future<Offset> getCursorScreenPoint() =>
      screenRetriever.getCursorScreenPoint();
}

typedef MonitorResolver = rust.MonitorResolution? Function({
  required rust.MonitorMode mode,
  required List<String> displayIds,
  required String primaryId,
  String? activeId,
  String? fixedId,
});

class MonitorService {
  MonitorService({
    MonitorDisplaySource? displaySource,
    MonitorResolver resolver = rust.resolveMonitor,
  })  : _displaySource = displaySource ?? const ScreenRetrieverDisplaySource(),
        _resolver = resolver;

  final MonitorDisplaySource _displaySource;
  final MonitorResolver _resolver;

  Future<Offset> getCursorPosition() => _displaySource.getCursorScreenPoint();

  Future<List<MonitorOption>> listAvailableMonitors() async {
    final displays = await _displaySource.getAllDisplays();
    final primary = await _displaySource.getPrimaryDisplay();

    return [
      for (var index = 0; index < displays.length; index++)
        MonitorOption(
          id: displays[index].id,
          label: _labelFor(
            displays[index],
            index: index,
            isPrimary: displays[index].id == primary.id,
          ),
        ),
    ];
  }

  Future<ResolvedMonitor?> resolve({
    required MonitorPreference mode,
    String? fixedMonitorId,
  }) async {
    final displays = await _displaySource.getAllDisplays();
    if (displays.isEmpty) return null;

    final primary = await _displaySource.getPrimaryDisplay();
    final activeId = mode == MonitorPreference.followActive
        ? _displayAt(
            displays,
            await _displaySource.getCursorScreenPoint(),
          )?.id
        : null;
    final resolution = _resolver(
      mode: switch (mode) {
        MonitorPreference.primary => rust.MonitorMode.primary,
        MonitorPreference.followActive => rust.MonitorMode.followActive,
        MonitorPreference.fixed => rust.MonitorMode.fixed,
      },
      displayIds: displays.map((display) => display.id).toList(),
      primaryId: primary.id,
      activeId: activeId,
      fixedId: fixedMonitorId,
    );
    if (resolution == null) return null;

    final selected = displays.firstWhere(
      (display) => display.id == resolution.displayId,
      orElse: () => primary,
    );
    return ResolvedMonitor(
      display: selected,
      usedFallback: resolution.usedFallback,
    );
  }

  static Offset topCenterPosition(Display display, Size windowSize) {
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    return Offset(
      visiblePosition.dx + (visibleSize.width - windowSize.width) / 2,
      visiblePosition.dy,
    );
  }

  static Display? _displayAt(List<Display> displays, Offset point) {
    Display? nearest;
    var nearestDistance = double.infinity;
    for (final display in displays) {
      final origin = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;
      final bounds = origin & size;
      if (bounds.contains(point)) return display;

      final closestX = point.dx.clamp(bounds.left, bounds.right).toDouble();
      final closestY = point.dy.clamp(bounds.top, bounds.bottom).toDouble();
      final dx = point.dx - closestX;
      final dy = point.dy - closestY;
      final distance = (dx * dx) + (dy * dy);
      if (distance < nearestDistance) {
        nearest = display;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  static String _labelFor(
    Display display, {
    required int index,
    required bool isPrimary,
  }) {
    final name = display.name?.trim();
    final title = name == null || name.isEmpty ? 'Display ${index + 1}' : name;
    final width = display.size.width.round();
    final height = display.size.height.round();
    final scale = ((display.scaleFactor ?? 1) * 100).round();
    final primarySuffix = isPrimary ? ' • Primary' : '';
    return '$title • $width×$height • $scale%$primarySuffix';
  }
}
