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

impl IslandState {
    /// Returns whether the state occupies visible screen space.
    pub const fn is_visible(self) -> bool {
        !matches!(self, Self::Hidden)
    }
}

#[cfg(test)]
mod tests {
    use super::IslandState;

    #[test]
    fn hidden_is_not_visible() {
        assert!(!IslandState::Hidden.is_visible());
    }

    #[test]
    fn collapsed_is_visible() {
        assert!(IslandState::Collapsed.is_visible());
    }
}

