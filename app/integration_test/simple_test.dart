import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/src/rust/api/clipboard.dart';
import 'package:islanddesk/src/rust/api/fullscreen.dart';
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
    expect(fullscreenPlatformSupported(), isTrue);
    expect(clipboardSecurityPlatformSupported(), isTrue);
    final clipboardSecurity = initializeClipboardSecurity();
    expect(clipboardSecurity.supported, isTrue);
    expect(clipboardSecurity.ready, isTrue);
    expect(clipboardSecurity.backend, 'windows_credential_manager');
    expect(clipboardSecurity.errorCode, isNull);
    final encrypted = encryptClipboardText(
      itemId: 'integration-item',
      plaintext: 'IslandDesk clipboard secret',
    );
    expect(encrypted.nonce, hasLength(12));
    expect(encrypted.ciphertext, isNotEmpty);
    expect(
      decryptClipboardText(
        itemId: 'integration-item',
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
      ),
      'IslandDesk clipboard secret',
    );
    expect(
      await watchClipboardText().first.timeout(const Duration(seconds: 5)),
      anyOf(isNull, isA<String>()),
    );
    expect(await isForegroundFullscreen(), isA<bool>());
    final media = await getCurrentMediaSession();
    final event = await watchMediaSessions().first.timeout(
          const Duration(seconds: 5),
        );
    if (event != null) {
      expect(event.sourceAppId, isNotEmpty);
    }
    if (media == null && event == null) {
      expect(await mediaPlayPause(), isFalse);
      expect(await mediaSeek(positionMs: BigInt.zero), isFalse);
    }
    if (media != null) {
      expect(media.sourceAppId, isNotEmpty);
    }
  });
}
