enum MonitorPreference {
  primary,
  followActive,
  fixed;

  String get storageValue => switch (this) {
        primary => 'primary',
        followActive => 'follow_active',
        fixed => 'fixed',
      };

  static MonitorPreference fromStorage(String? value) => switch (value) {
        'follow_active' => followActive,
        'fixed' => fixed,
        _ => primary,
      };
}

class AppSettings {
  const AppSettings({
    this.alwaysOnTop = true,
    this.animationsEnabled = true,
    this.hideInFullscreen = true,
    this.autoHidePanel = true,
    this.monitorPreference = MonitorPreference.primary,
    this.fixedMonitorId,
  });

  final bool alwaysOnTop;
  final bool animationsEnabled;
  final bool hideInFullscreen;
  final bool autoHidePanel;
  final MonitorPreference monitorPreference;
  final String? fixedMonitorId;

  AppSettings copyWith({
    bool? alwaysOnTop,
    bool? animationsEnabled,
    bool? hideInFullscreen,
    bool? autoHidePanel,
    MonitorPreference? monitorPreference,
    String? fixedMonitorId,
  }) {
    return AppSettings(
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      hideInFullscreen: hideInFullscreen ?? this.hideInFullscreen,
      autoHidePanel: autoHidePanel ?? this.autoHidePanel,
      monitorPreference: monitorPreference ?? this.monitorPreference,
      fixedMonitorId: fixedMonitorId ?? this.fixedMonitorId,
    );
  }
}
