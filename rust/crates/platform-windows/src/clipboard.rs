use std::sync::{Mutex, OnceLock};

use islanddesk_core::clipboard::{
    CLIPBOARD_KEY_LENGTH, ClipboardCipher, ClipboardKeyStore, ClipboardKeyStoreError,
};
use keyring::{Entry, Error};
use windows::{
    Win32::{
        Foundation::{HGLOBAL, HWND},
        System::{
            DataExchange::{
                AddClipboardFormatListener, CloseClipboard, GetClipboardData,
                IsClipboardFormatAvailable, OpenClipboard, RemoveClipboardFormatListener,
            },
            Memory::{GlobalLock, GlobalSize, GlobalUnlock},
        },
        UI::WindowsAndMessaging::{
            CreateWindowExW, DestroyWindow, GetMessageW, HWND_MESSAGE, KillTimer, MSG, SetTimer,
            WINDOW_EX_STYLE, WINDOW_STYLE, WM_CLIPBOARDUPDATE, WM_TIMER,
        },
    },
    core::w,
};

const KEYRING_SERVICE: &str = "IslandDesk";
const KEYRING_USER: &str = "clipboard-history-v1";

static CACHED_KEY: OnceLock<[u8; CLIPBOARD_KEY_LENGTH]> = OnceLock::new();
static KEY_INITIALIZATION: Mutex<()> = Mutex::new(());

pub struct WindowsClipboardKeyStore;

pub struct WindowsClipboardListener;

impl WindowsClipboardListener {
    pub fn watch_text(&self, mut emit: impl FnMut(Option<String>) -> bool) -> Result<(), String> {
        let window = ClipboardWindow::create()?;
        let mut current = read_text(window.handle()).unwrap_or(None);
        if !emit(current.clone()) {
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
            if matches!(message.message, WM_CLIPBOARDUPDATE | WM_TIMER) {
                // Retrying on the heartbeat recovers from another application
                // holding the clipboard during the original update event. The
                // duplicate also releases a cancelled Dart stream while idle.
                if let Ok(next) = read_text(window.handle()) {
                    current = next;
                }
                if !emit(current.clone()) {
                    return Ok(());
                }
            }
        }
    }
}

struct ClipboardWindow {
    handle: HWND,
}

impl ClipboardWindow {
    fn create() -> Result<Self, String> {
        let handle = unsafe {
            CreateWindowExW(
                WINDOW_EX_STYLE::default(),
                w!("STATIC"),
                w!("IslandDeskClipboardListener"),
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
        if let Err(error) = unsafe { AddClipboardFormatListener(handle) } {
            unsafe {
                let _ = DestroyWindow(handle);
            }
            return Err(error.to_string());
        }
        if unsafe { SetTimer(Some(handle), 1, 2_000, None) } == 0 {
            unsafe {
                let _ = RemoveClipboardFormatListener(handle);
                let _ = DestroyWindow(handle);
            }
            return Err(windows::core::Error::from_thread().to_string());
        }
        Ok(Self { handle })
    }

    fn handle(&self) -> HWND {
        self.handle
    }
}

impl Drop for ClipboardWindow {
    fn drop(&mut self) {
        unsafe {
            let _ = KillTimer(Some(self.handle), 1);
            let _ = RemoveClipboardFormatListener(self.handle);
            let _ = DestroyWindow(self.handle);
        }
    }
}

fn read_text(owner: HWND) -> Result<Option<String>, String> {
    const CF_UNICODETEXT: u32 = 13;
    if unsafe { IsClipboardFormatAvailable(CF_UNICODETEXT) }.is_err() {
        return Ok(None);
    }
    unsafe { OpenClipboard(Some(owner)) }.map_err(|error| error.to_string())?;
    let result = read_open_clipboard_text(CF_UNICODETEXT);
    let close_result = unsafe { CloseClipboard() }.map_err(|error| error.to_string());
    match (result, close_result) {
        (Err(error), _) | (Ok(_), Err(error)) => Err(error),
        (Ok(text), Ok(())) => Ok(text),
    }
}

fn read_open_clipboard_text(format: u32) -> Result<Option<String>, String> {
    let handle = unsafe { GetClipboardData(format) }.map_err(|error| error.to_string())?;
    let memory = HGLOBAL(handle.0);
    let size = unsafe { GlobalSize(memory) };
    if size < 2 {
        return Ok(None);
    }
    let pointer = unsafe { GlobalLock(memory) }.cast::<u16>();
    if pointer.is_null() {
        return Err(windows::core::Error::from_thread().to_string());
    }
    let units = unsafe { std::slice::from_raw_parts(pointer, size / 2) };
    let length = units
        .iter()
        .position(|unit| *unit == 0)
        .unwrap_or(units.len());
    let text = String::from_utf16_lossy(&units[..length]);
    let _ = unsafe { GlobalUnlock(memory) };
    Ok((!text.is_empty()).then_some(text))
}

impl ClipboardKeyStore for WindowsClipboardKeyStore {
    fn load_or_create_key(&self) -> Result<[u8; CLIPBOARD_KEY_LENGTH], ClipboardKeyStoreError> {
        if let Some(key) = CACHED_KEY.get() {
            return Ok(*key);
        }
        let _guard = KEY_INITIALIZATION.lock().map_err(|_| {
            ClipboardKeyStoreError::Unavailable("key initialization lock failed".into())
        })?;
        if let Some(key) = CACHED_KEY.get() {
            return Ok(*key);
        }

        let entry = Entry::new(KEYRING_SERVICE, KEYRING_USER)
            .map_err(|error| unavailable("open", error))?;
        let key = match entry.get_secret() {
            Ok(secret) => secret
                .try_into()
                .map_err(|_| ClipboardKeyStoreError::Corrupt)?,
            Err(Error::NoEntry) => {
                let generated = ClipboardCipher::generate_key();
                entry
                    .set_secret(&generated)
                    .map_err(|error| unavailable("write", error))?;
                generated
            }
            Err(error) => return Err(unavailable("read", error)),
        };
        let _ = CACHED_KEY.set(key);
        Ok(key)
    }
}

fn unavailable(operation: &str, error: Error) -> ClipboardKeyStoreError {
    ClipboardKeyStoreError::Unavailable(format!(
        "Windows Credential Manager {operation} failed: {error}"
    ))
}
