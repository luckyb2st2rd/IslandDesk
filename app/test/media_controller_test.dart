import 'package:flutter_test/flutter_test.dart';
import 'package:islanddesk/media/media_controller.dart';
import 'package:islanddesk/src/rust/api/media.dart';

void main() {
  test('loads the current session and refreshes after a command', () async {
    final gateway = _FakeMediaGateway();
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
}

class _FakeMediaGateway implements MediaGateway {
  int currentSessionCalls = 0;
  int playPauseCalls = 0;

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
}

final _testSession = MediaSession(
  sourceAppId: 'test.player',
  title: 'Test track',
  artist: 'Test artist',
  albumTitle: 'Test album',
  playbackState: MediaPlaybackState.playing,
  positionMs: BigInt.from(1000),
  durationMs: BigInt.from(5000),
  capabilities: const MediaCapabilities(
    canPlay: true,
    canPause: true,
    canNext: true,
    canPrevious: true,
    canSeek: true,
  ),
);
