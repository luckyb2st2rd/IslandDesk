//! Platform-neutral domain contracts for IslandDesk.

pub mod clipboard;
pub mod fullscreen;
pub mod media;
pub mod system_controls;

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

/// Policy used to choose the display that owns the Island window.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MonitorMode {
    Primary,
    FollowActive,
    Fixed,
}

/// Result of applying a monitor policy to the currently available displays.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MonitorSelection {
    pub display_id: String,
    pub used_fallback: bool,
}

/// Selects an available monitor, falling back to primary and then the first
/// enumerated display when the requested target is unavailable.
pub fn select_monitor(
    mode: MonitorMode,
    display_ids: &[String],
    primary_id: &str,
    active_id: Option<&str>,
    fixed_id: Option<&str>,
) -> Option<MonitorSelection> {
    if display_ids.is_empty() {
        return None;
    }

    let requested_id = match mode {
        MonitorMode::Primary => Some(primary_id),
        MonitorMode::FollowActive => active_id,
        MonitorMode::Fixed => fixed_id,
    };
    let requested = requested_id.and_then(|id| {
        display_ids
            .iter()
            .find(|candidate| candidate.as_str() == id)
    });
    if let Some(display_id) = requested {
        return Some(MonitorSelection {
            display_id: display_id.clone(),
            used_fallback: false,
        });
    }

    let fallback = display_ids
        .iter()
        .find(|candidate| candidate.as_str() == primary_id)
        .unwrap_or(&display_ids[0]);
    Some(MonitorSelection {
        display_id: fallback.clone(),
        used_fallback: true,
    })
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
    use super::{IslandEvent, IslandState, MonitorMode, select_monitor};

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

    #[test]
    fn monitor_policy_selects_primary_active_and_fixed_targets() {
        let displays = vec!["primary".to_owned(), "secondary".to_owned()];

        for (mode, active, fixed, expected) in [
            (MonitorMode::Primary, None, None, "primary"),
            (
                MonitorMode::FollowActive,
                Some("secondary"),
                None,
                "secondary",
            ),
            (MonitorMode::Fixed, None, Some("secondary"), "secondary"),
        ] {
            let selection = select_monitor(mode, &displays, "primary", active, fixed).unwrap();
            assert_eq!(selection.display_id, expected);
            assert!(!selection.used_fallback);
        }
    }

    #[test]
    fn unavailable_monitor_falls_back_to_primary() {
        let displays = vec!["primary".to_owned(), "secondary".to_owned()];
        let selection = select_monitor(
            MonitorMode::Fixed,
            &displays,
            "primary",
            None,
            Some("disconnected"),
        )
        .unwrap();

        assert_eq!(selection.display_id, "primary");
        assert!(selection.used_fallback);
    }

    #[test]
    fn missing_primary_falls_back_to_first_available_display() {
        let displays = vec!["secondary".to_owned()];
        let selection =
            select_monitor(MonitorMode::Primary, &displays, "missing", None, None).unwrap();

        assert_eq!(selection.display_id, "secondary");
        assert!(selection.used_fallback);
    }

    #[test]
    fn no_displays_produces_no_selection() {
        assert_eq!(
            select_monitor(MonitorMode::Primary, &[], "primary", None, None),
            None
        );
    }
}
