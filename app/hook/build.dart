import 'dart:io';

import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final effectiveInput = await _withoutSpacesInWindowsPackagePath(input);
    await const FlutterRustBridgeNativeAssetsBuilder(
      cratePath: '../rust/crates/bridge',
    ).run(input: effectiveInput, output: output);
  });
}

/// `native_toolchain_rust` currently parses Cargo dependency files by splitting
/// on spaces. Build through temporary links when a Windows checkout contains a
/// space so dependency tracking still receives valid paths.
Future<BuildInput> _withoutSpacesInWindowsPackagePath(BuildInput input) async {
  final packageRoot = Directory.fromUri(input.packageRoot);
  if (!Platform.isWindows || !packageRoot.path.contains(' ')) {
    return input;
  }

  final workspaceRoot = packageRoot.parent;
  final shortRoot = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'islanddesk_native_${_stablePathHash(workspaceRoot.path)}',
  );
  await shortRoot.create(recursive: true);

  final appLink = Link(
    '${shortRoot.path}${Platform.pathSeparator}${packageRoot.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty)}',
  );
  final rustLink = Link('${shortRoot.path}${Platform.pathSeparator}rust');
  await _ensureDirectoryLink(appLink, packageRoot.path);
  await _ensureDirectoryLink(
    rustLink,
    Directory('${workspaceRoot.path}${Platform.pathSeparator}rust').path,
  );

  return BuildInput({...input.json, 'package_root': appLink.path});
}

Future<void> _ensureDirectoryLink(Link link, String target) async {
  if (await link.exists()) {
    if ((await link.target()) == target) {
      return;
    }
    await link.delete();
  }
  await link.create(target);
}

String _stablePathHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
