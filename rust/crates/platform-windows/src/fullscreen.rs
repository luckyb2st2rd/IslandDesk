use std::mem::size_of;

use islanddesk_core::fullscreen::{FullscreenService, FullscreenServiceError, ScreenRect};
use windows::Win32::{
    Foundation::{POINT, RECT},
    Graphics::Gdi::{
        ClientToScreen, GetMonitorInfoW, MONITOR_DEFAULTTONEAREST, MONITORINFO, MonitorFromWindow,
    },
    UI::WindowsAndMessaging::{
        GetClientRect, GetDesktopWindow, GetForegroundWindow, GetShellWindow, IsWindowVisible,
    },
};

pub struct WindowsFullscreenService;

const EDGE_TOLERANCE_PIXELS: i32 = 2;

impl FullscreenService for WindowsFullscreenService {
    fn is_foreground_fullscreen(&self) -> Result<bool, FullscreenServiceError> {
        let window = unsafe { GetForegroundWindow() };
        if window.is_invalid()
            || window == unsafe { GetDesktopWindow() }
            || window == unsafe { GetShellWindow() }
            || !unsafe { IsWindowVisible(window) }.as_bool()
        {
            return Ok(false);
        }

        let mut client = RECT::default();
        unsafe { GetClientRect(window, &mut client) }.map_err(platform_error)?;
        let mut top_left = POINT {
            x: client.left,
            y: client.top,
        };
        let mut bottom_right = POINT {
            x: client.right,
            y: client.bottom,
        };
        if !unsafe { ClientToScreen(window, &mut top_left) }.as_bool()
            || !unsafe { ClientToScreen(window, &mut bottom_right) }.as_bool()
        {
            return Err(platform_error(windows::core::Error::from_thread()));
        }

        let monitor = unsafe { MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST) };
        if monitor.is_invalid() {
            return Ok(false);
        }
        let mut monitor_info = MONITORINFO {
            cbSize: size_of::<MONITORINFO>() as u32,
            ..Default::default()
        };
        if !unsafe { GetMonitorInfoW(monitor, &mut monitor_info) }.as_bool() {
            return Err(platform_error(windows::core::Error::from_thread()));
        }

        let client_bounds = ScreenRect {
            left: top_left.x,
            top: top_left.y,
            right: bottom_right.x,
            bottom: bottom_right.y,
        };
        let monitor_bounds = ScreenRect {
            left: monitor_info.rcMonitor.left,
            top: monitor_info.rcMonitor.top,
            right: monitor_info.rcMonitor.right,
            bottom: monitor_info.rcMonitor.bottom,
        };
        Ok(client_bounds.covers(monitor_bounds, EDGE_TOLERANCE_PIXELS))
    }
}

fn platform_error(error: windows::core::Error) -> FullscreenServiceError {
    FullscreenServiceError::Platform(error.to_string())
}
