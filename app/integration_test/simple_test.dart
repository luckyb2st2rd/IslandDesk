import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/src/rust/api/media.dart';
import 'package:islanddesk/src/rust/api/monitor.dart';
import 'package:islanddesk/src/rust/api/system.dart';
import 'package:islanddesk/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  tearDownAll(RustLib.dispose);
  testWidgets('calls the IslandDesk Rust core', (tester) async {
    final status = getCoreStatus();

    expect(status.name, 'IslandDesk Core');
    expect(status.version, '0.1.0');
    expect(status.targetOs, isNotEmpty);
    expect(status.targetArch, isNotEmpty);

    final monitor = resolveMonitor(
      mode: MonitorMode.fixed,
      displayIds: const ['primary', 'secondary'],
      primaryId: 'primary',
      fixedId: 'disconnected',
    );
    expect(monitor?.displayId, 'primary');
    expect(monitor?.usedFallback, isTrue);

    expect(mediaPlatformSupported(), isTrue);
    final media = await getCurrentMediaSession();
    if (media == null) {
      expect(await mediaPlayPause(), isFalse);
    } else {
      expect(media.sourceAppId, isNotEmpty);
    }
  });
}
