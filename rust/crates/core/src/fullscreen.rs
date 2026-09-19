use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScreenRect {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}

impl ScreenRect {
    pub const fn covers(self, target: Self, tolerance: i32) -> bool {
        self.left <= target.left + tolerance
            && self.top <= target.top + tolerance
            && self.right >= target.right - tolerance
            && self.bottom >= target.bottom - tolerance
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FullscreenServiceError {
    Platform(String),
}

impl Display for FullscreenServiceError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Platform(message) => write!(formatter, "fullscreen service error: {message}"),
        }
    }
}

impl std::error::Error for FullscreenServiceError {}

pub trait FullscreenService {
    fn is_foreground_fullscreen(&self) -> Result<bool, FullscreenServiceError>;
}

#[cfg(test)]
mod tests {
    use super::ScreenRect;

    const MONITOR: ScreenRect = ScreenRect {
        left: 0,
        top: 0,
        right: 1920,
        bottom: 1080,
    };

    #[test]
    fn full_monitor_client_bounds_are_fullscreen() {
        assert!(MONITOR.covers(MONITOR, 2));
        assert!(
            ScreenRect {
                left: -1,
                top: -1,
                right: 1921,
                bottom: 1081,
            }
            .covers(MONITOR, 2)
        );
    }

    #[test]
    fn maximized_work_area_is_not_fullscreen() {
        let maximized = ScreenRect {
            left: 0,
            top: 0,
            right: 1920,
            bottom: 1040,
        };
        assert!(!maximized.covers(MONITOR, 2));
    }
}
