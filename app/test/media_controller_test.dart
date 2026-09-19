import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/src/rust/api/media.dart';

void main() {
  test('loads the current session and refreshes after a command', () async {
    final gateway = _FakeMediaGateway();
    addTearDown(gateway.events.close);
    final controller = MediaController(
      gateway: gateway,
      refreshInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();
    final accepted = await controller.playPause();

    expect(controller.session?.title, 'Test track');
    expect(controller.isPlaying, isTrue);
    expect(accepted, isTrue);
    expect(gateway.currentSessionCalls, 2);
    expect(gateway.playPauseCalls, 1);
  });

  test('converts gateway failures into non-fatal controller state', () async {
    final controller = MediaController(
      gateway: _FailingMediaGateway(),
      refreshInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.session, isNull);
    expect(controller.errorMessage, contains('unavailable'));
  });

  test('accepts native session events and sends seek commands', () async {
    final gateway = _FakeMediaGateway();
    addTearDown(gateway.events.close);
    final controller = MediaController(
      gateway: gateway,
      refreshInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();
    gateway.events.add(_testSession.copyWith(title: 'Native update'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.session?.title, 'Native update');
    expect(controller.session?.artwork, [1, 2, 3]);
    controller.previewSeek(2500);
    final accepted = await controller.seek(controller.displayPositionMs);

    expect(controller.session?.title, 'Test track');
    expect(accepted, isTrue);
    expect(gateway.seekPositions, [2500]);
  });
}

class _FakeMediaGateway implements MediaGateway {
  final events = StreamController<MediaSession?>.broadcast();
  int currentSessionCalls = 0;
  int playPauseCalls = 0;
  final seekPositions = <int>[];

  @override
  bool get isSupported => true;

  @override
  Future<MediaSession?> currentSession() async {
    currentSessionCalls++;
    return _testSession;
  }

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
  Future<bool> seek(int positionMs) async {
    seekPositions.add(positionMs);
    return true;
  }

  @override
  Stream<MediaSession?> watchSessions() => events.stream;
}

class _FailingMediaGateway implements MediaGateway {
  @override
  bool get isSupported => true;

  @override
  Future<MediaSession?> currentSession() =>
      Future.error(StateError('media unavailable'));

  @override
  Future<bool> next() async => false;

  @override
  Future<bool> playPause() async => false;

  @override
  Future<bool> previous() async => false;

  @override
  Future<bool> seek(int positionMs) async => false;

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
  positionMs: BigInt.from(1000),
  durationMs: BigInt.from(5000),
  artwork: Uint8List.fromList([1, 2, 3]),
  artworkContentType: 'image/png',
  capabilities: const MediaCapabilities(
    canPlay: true,
    canPause: true,
    canNext: true,
    canPrevious: true,
    canSeek: true,
  ),
);

extension on MediaSession {
  MediaSession copyWith({String? title}) => MediaSession(
        sourceAppId: sourceAppId,
        sourceAppName: sourceAppName,
        title: title ?? this.title,
        artist: artist,
        albumTitle: albumTitle,
        playbackState: playbackState,
        positionMs: positionMs,
        durationMs: durationMs,
        artwork: artwork,
        artworkContentType: artworkContentType,
        capabilities: capabilities,
      );
}
