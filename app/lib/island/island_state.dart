import 'dart:ui';

enum IslandState {
  hidden,
  collapsed,
  peek,
  expanded,
  moduleExpanded,
  transientHud,
}

extension IslandStatePresentation on IslandState {
  bool get isVisible => this != IslandState.hidden;

  bool get showsDetails => switch (this) {
        IslandState.expanded || IslandState.moduleExpanded => true,
        _ => false,
      };

  Size get surfaceSize => switch (this) {
        IslandState.hidden => const Size(180, 42),
        IslandState.collapsed => const Size(196, 44),
        IslandState.peek => const Size(252, 52),
        IslandState.expanded => const Size(420, 180),
        IslandState.moduleExpanded => const Size(520, 360),
        IslandState.transientHud => const Size(280, 64),
      };
}
