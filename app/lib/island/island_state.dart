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
}
