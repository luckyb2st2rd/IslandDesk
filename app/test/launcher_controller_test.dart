import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/launcher/launcher_controller.dart';
import 'package:islanddesk/launcher/launcher_item.dart';
import 'package:islanddesk/launcher/launcher_repository.dart';

void main() {
  test('adds, reorders, launches and removes applications', () async {
    final directory = await Directory.systemTemp.createTemp('islanddesk-apps');
    final alpha = File('${directory.path}/Alpha_App.exe');
    final beta = File('${directory.path}/Beta.exe');
    await alpha.writeAsBytes(const []);
    await beta.writeAsBytes(const []);
    final repository = _MemoryLauncherRepository();
    final gateway = _FakeLauncherGateway();
    final controller = LauncherController(
      repository: repository,
      gateway: gateway,
    );
    await controller.load();

    expect(await controller.addPath(alpha.path), isTrue);
    expect(await controller.addPath(beta.path), isTrue);
    expect(await controller.addPath(alpha.path), isFalse);
    expect(controller.items.map((item) => item.displayName), [
      'Alpha App',
      'Beta',
    ]);

    await controller.reorder(1, 0);
    expect(controller.items.map((item) => item.displayName), [
      'Beta',
      'Alpha App',
    ]);
    expect(repository.order, controller.items.map((item) => item.id));

    final betaId = controller.items.first.id;
    expect(await controller.launch(betaId), isTrue);
    expect(gateway.launched?.displayName, 'Beta');

    await controller.remove(betaId);
    expect(controller.items.single.displayName, 'Alpha App');
    await controller.close();
    expect(repository.closed, isTrue);
    controller.dispose();
    await directory.delete(recursive: true);
  });

  test('marks an application missing instead of launching it', () async {
    final directory = await Directory.systemTemp.createTemp('islanddesk-apps');
    final executable = File('${directory.path}/Temporary.exe');
    await executable.writeAsBytes(const []);
    final gateway = _FakeLauncherGateway();
    final controller = LauncherController(gateway: gateway);
    await controller.addPath(executable.path);
    final id = controller.items.single.id;
    await executable.delete();

    expect(await controller.launch(id), isFalse);
    expect(controller.items.single.isMissing, isTrue);
    expect(gateway.launched, isNull);
    controller.dispose();
    await directory.delete(recursive: true);
  });
}

class _FakeLauncherGateway implements LauncherGateway {
  LauncherItem? launched;

  @override
  bool get isSupported => true;

  @override
  Future<bool> launch(LauncherItem item) async {
    launched = item;
    return true;
  }
}

class _MemoryLauncherRepository implements LauncherRepository {
  final List<LauncherItem> values = [];
  List<String> order = [];
  bool closed = false;

  @override
  Future<List<LauncherItem>> load() async => List.of(values);

  @override
  Future<void> save(LauncherItem item) async => values.add(item);

  @override
  Future<void> reorder(List<String> ids) async => order = List.of(ids);

  @override
  Future<void> remove(String id) async {
    values.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> close() async => closed = true;
}
