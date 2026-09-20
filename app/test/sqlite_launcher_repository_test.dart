import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/launcher/launcher_item.dart';
import 'package:islanddesk/launcher/sqlite_launcher_repository.dart';

void main() {
  test('persists launcher items and their custom order', () async {
    final repository = SqliteLauncherRepository.openAtPath(':memory:');
    final first = LauncherItem(
      id: 'first',
      executablePath: 'C:/Apps/First.exe',
      displayName: 'First',
      arguments: '--new-window',
      workingDirectory: 'C:/Apps',
      position: 0,
      createdAt: DateTime.utc(2026, 9, 21, 10),
    );
    final second = LauncherItem(
      id: 'second',
      executablePath: 'C:/Apps/Second.exe',
      displayName: 'Second',
      position: 1,
      createdAt: DateTime.utc(2026, 9, 21, 11),
    );

    await repository.save(first);
    await repository.save(second);
    await repository.reorder(['second', 'first']);

    var loaded = await repository.load();
    expect(loaded.map((item) => item.id), ['second', 'first']);
    expect(loaded.last.arguments, '--new-window');
    expect(loaded.last.workingDirectory, 'C:/Apps');

    await repository.remove('second');
    loaded = await repository.load();
    expect(loaded.single.id, 'first');
    await repository.close();
  });
}
