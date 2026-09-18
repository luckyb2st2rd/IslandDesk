class AppSettings {
  const AppSettings({
    this.alwaysOnTop = true,
    this.animationsEnabled = true,
  });

  final bool alwaysOnTop;
  final bool animationsEnabled;

  AppSettings copyWith({
    bool? alwaysOnTop,
    bool? animationsEnabled,
  }) {
    return AppSettings(
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    );
  }
}
