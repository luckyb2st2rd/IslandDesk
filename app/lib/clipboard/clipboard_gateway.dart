import 'package:islanddesk/src/rust/api/clipboard.dart';

abstract interface class ClipboardGateway {
  bool get isSupported;

  Stream<String?> watchText();
}

class RustClipboardGateway implements ClipboardGateway {
  const RustClipboardGateway();

  @override
  bool get isSupported => clipboardSecurityPlatformSupported();

  @override
  Stream<String?> watchText() => watchClipboardText();
}
