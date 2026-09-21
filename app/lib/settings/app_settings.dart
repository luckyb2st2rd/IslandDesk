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

enum GlobalHotkeyShortcut {
  ctrlAltSpace('ctrl_alt_space', 'Ctrl + Alt + Space'),
  ctrlShiftSpace('ctrl_shift_space', 'Ctrl + Shift + Space'),
  altShiftSpace('alt_shift_space', 'Alt + Shift + Space'),
  ctrlAltI('ctrl_alt_i', 'Ctrl + Alt + I'),
  disabled('disabled', 'Disabled');

  const GlobalHotkeyShortcut(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static GlobalHotkeyShortcut fromStorage(String? value) => values.firstWhere(
        (shortcut) => shortcut.storageValue == value,
        orElse: () => ctrlAltSpace,
      );
}

class AppSettings {
  const AppSettings({
    this.alwaysOnTop = true,
    this.animationsEnabled = true,
    this.hideInFullscreen = true,
    this.autoHidePanel = true,
    this.monitorPreference = MonitorPreference.primary,
    this.fixedMonitorId,
    this.globalHotkey = GlobalHotkeyShortcut.ctrlAltSpace,
  });

  final bool alwaysOnTop;
  final bool animationsEnabled;
  final bool hideInFullscreen;
  final bool autoHidePanel;
  final MonitorPreference monitorPreference;
  final String? fixedMonitorId;
  final GlobalHotkeyShortcut globalHotkey;

  AppSettings copyWith({
    bool? alwaysOnTop,
    bool? animationsEnabled,
    bool? hideInFullscreen,
    bool? autoHidePanel,
    MonitorPreference? monitorPreference,
    String? fixedMonitorId,
    GlobalHotkeyShortcut? globalHotkey,
  }) {
    return AppSettings(
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      hideInFullscreen: hideInFullscreen ?? this.hideInFullscreen,
      autoHidePanel: autoHidePanel ?? this.autoHidePanel,
      monitorPreference: monitorPreference ?? this.monitorPreference,
      fixedMonitorId: fixedMonitorId ?? this.fixedMonitorId,
      globalHotkey: globalHotkey ?? this.globalHotkey,
    );
  }
}
