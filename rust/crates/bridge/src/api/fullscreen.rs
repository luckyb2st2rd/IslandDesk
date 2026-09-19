#[cfg(windows)]
use islanddesk_core::fullscreen::FullscreenService;

#[flutter_rust_bridge::frb(sync)]
pub fn fullscreen_platform_supported() -> bool {
    cfg!(windows)
}

pub fn is_foreground_fullscreen() -> Result<bool, String> {
    detect_fullscreen()
}

#[cfg(windows)]
fn detect_fullscreen() -> Result<bool, String> {
    islanddesk_platform_windows::WindowsFullscreenService
        .is_foreground_fullscreen()
        .map_err(|error| error.to_string())
}

#[cfg(not(windows))]
fn detect_fullscreen() -> Result<bool, String> {
    Ok(false)
}
