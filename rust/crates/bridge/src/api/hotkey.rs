use crate::frb_generated::StreamSink;
use islanddesk_core::hotkey::GlobalHotkey;

pub struct GlobalHotkeyEvent {
    pub activated: bool,
    pub registered: bool,
    pub error_code: Option<String>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn global_hotkey_platform_supported() -> bool {
    cfg!(windows)
}

#[flutter_rust_bridge::frb(sync)]
pub fn configure_global_hotkey(shortcut: String) -> Result<(), String> {
    configure(GlobalHotkey::from_storage(&shortcut))
}

pub fn watch_global_hotkey(sink: StreamSink<GlobalHotkeyEvent>) -> Result<(), String> {
    watch(move |event| sink.add(event).is_ok())
}

#[cfg(windows)]
fn configure(shortcut: GlobalHotkey) -> Result<(), String> {
    islanddesk_platform_windows::WindowsHotkeyListener::configure(shortcut)
}

#[cfg(not(windows))]
fn configure(_shortcut: GlobalHotkey) -> Result<(), String> {
    Ok(())
}

#[cfg(windows)]
fn watch(mut emit: impl FnMut(GlobalHotkeyEvent) -> bool) -> Result<(), String> {
    islanddesk_platform_windows::WindowsHotkeyListener.watch(move |event| {
        emit(GlobalHotkeyEvent {
            activated: event.activated,
            registered: event.registered,
            error_code: event.error_code,
        })
    })
}

#[cfg(not(windows))]
fn watch(mut emit: impl FnMut(GlobalHotkeyEvent) -> bool) -> Result<(), String> {
    let _ = emit(GlobalHotkeyEvent {
        activated: false,
        registered: false,
        error_code: None,
    });
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::global_hotkey_platform_supported;

    #[test]
    fn reports_global_hotkey_platform_support() {
        assert_eq!(global_hotkey_platform_supported(), cfg!(windows));
    }
}
