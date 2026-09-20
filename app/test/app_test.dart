import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/app.dart';
import 'package:islanddesk/application/application_controller.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/src/rust/api/media.dart';
import 'package:islanddesk/src/rust/api/system_controls.dart';
import 'package:islanddesk/system_controls/system_controls_controller.dart';

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
    expect(find.byKey(const ValueKey('media-artwork')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media-play-pause')));
    await tester.pump();
    expect(gateway.playPauseCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('switches between all island modules', (tester) async {
    final systemControls = SystemControlsController(
      gateway: _FakeSystemControlsGateway(),
      refreshInterval: const Duration(hours: 1),
    );
    await systemControls.start();
    final controller = ApplicationController(
      clipboardSecurityReady: true,
      clipboardSecurityBackend: 'windows_credential_manager',
      systemControlsController: systemControls,
    );
    await tester.pumpWidget(IslandDeskApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('island-surface')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('module-shelf')));
    await tester.pump();
    expect(find.byKey(const ValueKey('shelf-content')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('module-clipboard')));
    await tester.pump();
    expect(find.byKey(const ValueKey('clipboard-content')), findsOneWidget);
    expect(find.text('Protected'), findsOneWidget);
    expect(find.textContaining('Windows Credential Manager'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clipboard-pause')));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clipboard-exclusions')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('clipboard-exclusions-editor')),
      'vault.exe',
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-exclusions-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 sensitive apps excluded'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('module-timer')));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('timer-toggle')), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('module-notes')));
    await tester.pump();
    expect(find.byKey(const ValueKey('notes-editor')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('notes-editor')),
      'IslandDesk note',
    );

    await tester.tap(find.byKey(const ValueKey('module-launcher')));
    await tester.pump();
    expect(find.byKey(const ValueKey('launcher-content')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('module-system')));
    await tester.pump();
    expect(find.byKey(const ValueKey('system-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('system-output-volume')), findsOneWidget);
    expect(find.byKey(const ValueKey('system-input-mute')), findsOneWidget);
    expect(find.byKey(const ValueKey('system-keep-awake')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _FakeSystemControlsGateway implements SystemControlsGateway {
  @override
  bool get isSupported => true;

  SystemControlsState get _state => const SystemControlsState(
        output: AudioEndpointState(
          available: true,
          volumePercent: 50,
          muted: false,
        ),
        input: AudioEndpointState(
          available: true,
          volumePercent: 75,
          muted: false,
        ),
        keepAwake: false,
      );

  @override
  Future<SystemControlsState> currentState() async => _state;

  @override
  Future<SystemControlsState> setInputMuted(bool muted) async => _state;

  @override
  Future<SystemControlsState> setKeepAwake(bool active) async => _state;

  @override
  Future<SystemControlsState> setOutputMuted(bool muted) async => _state;

  @override
  Future<SystemControlsState> setOutputVolume(int volumePercent) async =>
      _state;
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

  @override
  Future<bool> seek(int positionMs) async => true;

  @override
  Stream<MediaSession?> watchSessions() => const Stream.empty();
}

final _testSession = MediaSession(
  sourceAppId: 'test.player',
  sourceAppName: 'Test Player',
  title: 'Test track',
  artist: 'Test artist',
  albumTitle: 'Test album',
  playbackState: MediaPlaybackState.playing,
  positionMs: BigInt.from(1),
  durationMs: BigInt.from(10),
  artwork: Uint8List(0),
  artworkContentType: '',
  capabilities: MediaCapabilities(
    canPlay: true,
    canPause: true,
    canNext: true,
    canPrevious: true,
    canSeek: true,
  ),
);
