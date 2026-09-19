import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/src/rust/api/media.dart';

void main() {
  testWidgets('expands the island when clicked', (tester) async {
    await tester.pumpWidget(const IslandDeskApp());

    expect(find.text('IslandDesk'), findsWidgets);
    expect(find.text('Nothing playing'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('island-surface')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing playing'), findsOneWidget);
    expect(find.byKey(const ValueKey('media-play-pause')), findsOneWidget);
  });

  testWidgets('shows media metadata and sends playback commands',
      (tester) async {
    final gateway = _FakeMediaGateway();
    final media = MediaController(
      gateway: gateway,
      refreshInterval: const Duration(hours: 1),
    );
    await media.start();
    final controller = ApplicationController(mediaController: media);

    await tester.pumpWidget(IslandDeskApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('island-surface')));
    await tester.pumpAndSettle();

    expect(find.text('Test track'), findsOneWidget);
    expect(find.text('Test artist'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media-play-pause')));
    await tester.pump();
    expect(gateway.playPauseCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _FakeMediaGateway implements MediaGateway {
  int playPauseCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<MediaSession?> currentSession() async => _testSession;

  @override
  Future<bool> next() async => true;

  @override
  Future<bool> playPause() async {
    playPauseCalls++;
    return true;
  }

  @override
  Future<bool> previous() async => true;
}

final _testSession = MediaSession(
  sourceAppId: 'test.player',
  title: 'Test track',
  artist: 'Test artist',
  albumTitle: 'Test album',
  playbackState: MediaPlaybackState.playing,
  positionMs: BigInt.from(1),
  durationMs: BigInt.from(10),
  capabilities: MediaCapabilities(
    canPlay: true,
    canPause: true,
    canNext: true,
    canPrevious: true,
    canSeek: true,
  ),
);
