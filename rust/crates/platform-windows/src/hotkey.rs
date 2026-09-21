use std::{
    ffi::c_void,
    sync::atomic::{AtomicIsize, AtomicU8, Ordering},
};

use islanddesk_core::hotkey::GlobalHotkey;
use windows::Win32::{
    Foundation::{HWND, LPARAM, WPARAM},
    UI::{
        Input::KeyboardAndMouse::{
            HOT_KEY_MODIFIERS, MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, MOD_SHIFT, RegisterHotKey,
            UnregisterHotKey,
        },
        WindowsAndMessaging::{
            CreateWindowExW, DestroyWindow, GetMessageW, HWND_MESSAGE, KillTimer, MSG,
            PostMessageW, SetTimer, WINDOW_EX_STYLE, WINDOW_STYLE, WM_APP, WM_HOTKEY, WM_TIMER,
        },
    },
};
use windows::core::w;

const HOTKEY_ID: i32 = 0x4944;
const HEARTBEAT_TIMER_ID: usize = 1;
const HEARTBEAT_INTERVAL_MS: u32 = 500;
const RECONFIGURE_MESSAGE: u32 = WM_APP + 0x49;
const VK_SPACE: u32 = 0x20;
const VK_I: u32 = 0x49;

static CONFIGURED_HOTKEY: AtomicU8 = AtomicU8::new(0);
static LISTENER_WINDOW: AtomicIsize = AtomicIsize::new(0);

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WindowsHotkeyEvent {
    pub activated: bool,
    pub registered: bool,
    pub error_code: Option<String>,
}

pub struct WindowsHotkeyListener;

impl WindowsHotkeyListener {
    pub fn configure(shortcut: GlobalHotkey) -> Result<(), String> {
        CONFIGURED_HOTKEY.store(shortcut_code(shortcut), Ordering::Release);
        let raw_window = LISTENER_WINDOW.load(Ordering::Acquire);
        if raw_window == 0 {
            return Ok(());
        }
        unsafe {
            PostMessageW(
                Some(HWND(raw_window as *mut c_void)),
                RECONFIGURE_MESSAGE,
                WPARAM(0),
                LPARAM(0),
            )
        }
        .map_err(|error| error.to_string())
    }

    pub fn watch(&self, mut emit: impl FnMut(WindowsHotkeyEvent) -> bool) -> Result<(), String> {
        let window = HotkeyWindow::create()?;
        let mut registration = window.register(configured_hotkey());
        if !emit(status_event(&registration, false)) {
            return Ok(());
        }

        loop {
            let mut message = MSG::default();
            let result = unsafe { GetMessageW(&mut message, Some(window.handle()), 0, 0) };
            if result.0 == -1 {
                return Err(windows::core::Error::from_thread().to_string());
            }
            if !result.as_bool() {
                return Ok(());
            }
            let event = match message.message {
                WM_HOTKEY => WindowsHotkeyEvent {
                    activated: true,
                    registered: registration.is_ok(),
                    error_code: registration.as_ref().err().cloned(),
                },
                RECONFIGURE_MESSAGE => {
                    window.unregister();
                    registration = window.register(configured_hotkey());
                    status_event(&registration, false)
                }
                WM_TIMER => status_event(&registration, false),
                _ => continue,
            };
            if !emit(event) {
                return Ok(());
            }
        }
    }
}

struct HotkeyWindow {
    handle: HWND,
}

impl HotkeyWindow {
    fn create() -> Result<Self, String> {
        let handle = unsafe {
            CreateWindowExW(
                WINDOW_EX_STYLE::default(),
                w!("STATIC"),
                w!("IslandDeskGlobalHotkey"),
                WINDOW_STYLE::default(),
                0,
                0,
                0,
                0,
                Some(HWND_MESSAGE),
                None,
                None,
                None,
            )
        }
        .map_err(|error| error.to_string())?;
        if unsafe {
            SetTimer(
                Some(handle),
                HEARTBEAT_TIMER_ID,
                HEARTBEAT_INTERVAL_MS,
                None,
            )
        } == 0
        {
            unsafe {
                let _ = DestroyWindow(handle);
            }
            return Err(windows::core::Error::from_thread().to_string());
        }
        LISTENER_WINDOW.store(handle.0 as isize, Ordering::Release);
        Ok(Self { handle })
    }

    const fn handle(&self) -> HWND {
        self.handle
    }

    fn register(&self, shortcut: GlobalHotkey) -> Result<bool, String> {
        let Some((modifiers, key)) = windows_binding(shortcut) else {
            return Ok(false);
        };
        unsafe { RegisterHotKey(Some(self.handle), HOTKEY_ID, modifiers, key) }
            .map(|()| true)
            .map_err(|_| "hotkey_unavailable".to_owned())
    }

    fn unregister(&self) {
        unsafe {
            let _ = UnregisterHotKey(Some(self.handle), HOTKEY_ID);
        }
    }
}

impl Drop for HotkeyWindow {
    fn drop(&mut self) {
        LISTENER_WINDOW.store(0, Ordering::Release);
        self.unregister();
        unsafe {
            let _ = KillTimer(Some(self.handle), HEARTBEAT_TIMER_ID);
            let _ = DestroyWindow(self.handle);
        }
    }
}

fn status_event(registration: &Result<bool, String>, activated: bool) -> WindowsHotkeyEvent {
    WindowsHotkeyEvent {
        activated,
        registered: registration.as_ref().copied().unwrap_or(false),
        error_code: registration.as_ref().err().cloned(),
    }
}

fn configured_hotkey() -> GlobalHotkey {
    match CONFIGURED_HOTKEY.load(Ordering::Acquire) {
        1 => GlobalHotkey::CtrlShiftSpace,
        2 => GlobalHotkey::AltShiftSpace,
        3 => GlobalHotkey::CtrlAltI,
        4 => GlobalHotkey::Disabled,
        _ => GlobalHotkey::CtrlAltSpace,
    }
}

const fn shortcut_code(shortcut: GlobalHotkey) -> u8 {
    match shortcut {
        GlobalHotkey::CtrlAltSpace => 0,
        GlobalHotkey::CtrlShiftSpace => 1,
        GlobalHotkey::AltShiftSpace => 2,
        GlobalHotkey::CtrlAltI => 3,
        GlobalHotkey::Disabled => 4,
    }
}

fn windows_binding(shortcut: GlobalHotkey) -> Option<(HOT_KEY_MODIFIERS, u32)> {
    match shortcut {
        GlobalHotkey::CtrlAltSpace => Some((MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, VK_SPACE)),
        GlobalHotkey::CtrlShiftSpace => Some((MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, VK_SPACE)),
        GlobalHotkey::AltShiftSpace => Some((MOD_ALT | MOD_SHIFT | MOD_NOREPEAT, VK_SPACE)),
        GlobalHotkey::CtrlAltI => Some((MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, VK_I)),
        GlobalHotkey::Disabled => None,
    }
}

#[cfg(test)]
mod tests {
    use super::{GlobalHotkey, shortcut_code, windows_binding};

    #[test]
    fn maps_supported_shortcuts_and_disables_registration() {
        assert!(windows_binding(GlobalHotkey::CtrlAltSpace).is_some());
        assert!(windows_binding(GlobalHotkey::CtrlAltI).is_some());
        assert!(windows_binding(GlobalHotkey::Disabled).is_none());
        assert_eq!(shortcut_code(GlobalHotkey::AltShiftSpace), 2);
    }
}
