import 'package:islanddesk/src/rust/api/clipboard.dart';

abstract interface class ClipboardGateway {
  bool get isSupported;

  Stream<ClipboardEvent> watchText();
}

class ClipboardEvent {
  const ClipboardEvent({
    required this.text,
    required this.sourceApplication,
    this.isHeartbeat = false,
  });

  final String? text;
  final String sourceApplication;
  final bool isHeartbeat;
}

class RustClipboardGateway implements ClipboardGateway {
  const RustClipboardGateway();

  @override
  bool get isSupported => clipboardSecurityPlatformSupported();

  @override
  Stream<ClipboardEvent> watchText() => watchClipboardText().map(
        (event) => ClipboardEvent(
          text: event.text,
          sourceApplication: event.sourceApplication,
          isHeartbeat: event.isHeartbeat,
        ),
      );
}
