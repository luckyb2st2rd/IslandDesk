//! Platform-neutral domain contracts for IslandDesk.

/// The visible state of the Island surface.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IslandState {
    Hidden,
    Collapsed,
    Peek,
    Expanded,
    ModuleExpanded,
    TransientHud,
}

/// Inputs that drive the platform-neutral Island state machine.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IslandEvent {
    PointerEntered,
    PointerExited,
    ToggleExpanded,
    Hide,
    ShowTransientHud,
    Collapse,
}

impl IslandState {
    /// Returns whether the state occupies visible screen space.
    pub const fn is_visible(self) -> bool {
        !matches!(self, Self::Hidden)
    }

    /// Applies one deterministic UI or system event.
    pub const fn transition(self, event: IslandEvent) -> Self {
        match event {
            IslandEvent::PointerEntered if matches!(self, Self::Collapsed) => Self::Peek,
            IslandEvent::PointerExited if matches!(self, Self::Peek) => Self::Collapsed,
            IslandEvent::ToggleExpanded if matches!(self, Self::Expanded) => Self::Collapsed,
            IslandEvent::ToggleExpanded => Self::Expanded,
            IslandEvent::Hide => Self::Hidden,
            IslandEvent::ShowTransientHud => Self::TransientHud,
            IslandEvent::Collapse => Self::Collapsed,
            _ => self,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{IslandEvent, IslandState};

    #[test]
    fn hidden_is_not_visible() {
        assert!(!IslandState::Hidden.is_visible());
    }

    #[test]
    fn collapsed_is_visible() {
        assert!(IslandState::Collapsed.is_visible());
    }

    #[test]
    fn hover_transition_returns_to_collapsed() {
        let peek = IslandState::Collapsed.transition(IslandEvent::PointerEntered);
        assert_eq!(peek, IslandState::Peek);
        assert_eq!(
            peek.transition(IslandEvent::PointerExited),
            IslandState::Collapsed
        );
    }

    #[test]
    fn expanded_state_toggles_closed() {
        assert_eq!(
            IslandState::Expanded.transition(IslandEvent::ToggleExpanded),
            IslandState::Collapsed
        );
    }
}
