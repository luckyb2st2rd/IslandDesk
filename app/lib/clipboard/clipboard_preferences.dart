class ClipboardPreferences {
  const ClipboardPreferences({
    this.capturePaused = false,
    this.excludedApplications = defaultExcludedApplications,
  });

  static const defaultExcludedApplications = <String>[
    '1password.exe',
    'bitwarden.exe',
    'dashlane.exe',
    'keepass.exe',
    'keepassxc.exe',
    'protonpass.exe',
  ];

  final bool capturePaused;
  final List<String> excludedApplications;

  ClipboardPreferences copyWith({
    bool? capturePaused,
    List<String>? excludedApplications,
  }) =>
      ClipboardPreferences(
        capturePaused: capturePaused ?? this.capturePaused,
        excludedApplications: excludedApplications ?? this.excludedApplications,
      );
}
