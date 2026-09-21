#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum GlobalHotkey {
    #[default]
    CtrlAltSpace,
    CtrlShiftSpace,
    AltShiftSpace,
    CtrlAltI,
    Disabled,
}

impl GlobalHotkey {
    pub const fn storage_value(self) -> &'static str {
        match self {
            Self::CtrlAltSpace => "ctrl_alt_space",
            Self::CtrlShiftSpace => "ctrl_shift_space",
            Self::AltShiftSpace => "alt_shift_space",
            Self::CtrlAltI => "ctrl_alt_i",
            Self::Disabled => "disabled",
        }
    }

    pub fn from_storage(value: &str) -> Self {
        match value {
            "ctrl_shift_space" => Self::CtrlShiftSpace,
            "alt_shift_space" => Self::AltShiftSpace,
            "ctrl_alt_i" => Self::CtrlAltI,
            "disabled" => Self::Disabled,
            _ => Self::CtrlAltSpace,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::GlobalHotkey;

    #[test]
    fn parses_persisted_shortcuts_with_a_safe_default() {
        assert_eq!(
            GlobalHotkey::from_storage("ctrl_shift_space"),
            GlobalHotkey::CtrlShiftSpace
        );
        assert_eq!(
            GlobalHotkey::from_storage("unknown"),
            GlobalHotkey::CtrlAltSpace
        );
        assert_eq!(GlobalHotkey::Disabled.storage_value(), "disabled");
    }
}
