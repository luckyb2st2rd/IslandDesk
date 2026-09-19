use std::sync::{Mutex, OnceLock};

use islanddesk_core::clipboard::{
    CLIPBOARD_KEY_LENGTH, ClipboardCipher, ClipboardKeyStore, ClipboardKeyStoreError,
};
use keyring::{Entry, Error};

const KEYRING_SERVICE: &str = "IslandDesk";
const KEYRING_USER: &str = "clipboard-history-v1";

static CACHED_KEY: OnceLock<[u8; CLIPBOARD_KEY_LENGTH]> = OnceLock::new();
static KEY_INITIALIZATION: Mutex<()> = Mutex::new(());

pub struct WindowsClipboardKeyStore;

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
