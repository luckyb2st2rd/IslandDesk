class LauncherItem {
  const LauncherItem({
    required this.id,
    required this.executablePath,
    required this.displayName,
    required this.position,
    required this.createdAt,
    this.arguments,
    this.workingDirectory,
    this.isMissing = false,
  });

  final String id;
  final String executablePath;
  final String displayName;
  final String? arguments;
  final String? workingDirectory;
  final int position;
  final DateTime createdAt;
  final bool isMissing;

  LauncherItem copyWith({
    String? executablePath,
    String? displayName,
    String? arguments,
    String? workingDirectory,
    int? position,
    bool? isMissing,
  }) =>
      LauncherItem(
        id: id,
        executablePath: executablePath ?? this.executablePath,
        displayName: displayName ?? this.displayName,
        arguments: arguments ?? this.arguments,
        workingDirectory: workingDirectory ?? this.workingDirectory,
        position: position ?? this.position,
        createdAt: createdAt,
        isMissing: isMissing ?? this.isMissing,
      );
}
