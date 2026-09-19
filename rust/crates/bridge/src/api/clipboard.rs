use islanddesk_core::clipboard::ClipboardKeyStoreError;
use islanddesk_core::clipboard::{
    CLIPBOARD_NONCE_LENGTH, ClipboardCipher, ClipboardKeyStore, EncryptedClipboardPayload,
};

use crate::frb_generated::StreamSink;

pub struct ClipboardSecurityStatus {
    pub supported: bool,
    pub ready: bool,
    pub backend: String,
    pub error_code: Option<String>,
}

pub struct ClipboardEncryptedData {
    pub nonce: Vec<u8>,
    pub ciphertext: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn clipboard_security_platform_supported() -> bool {
    cfg!(windows)
}

#[flutter_rust_bridge::frb(sync)]
pub fn initialize_clipboard_security() -> ClipboardSecurityStatus {
    initialize()
}

#[flutter_rust_bridge::frb(sync)]
pub fn encrypt_clipboard_text(
    item_id: String,
    plaintext: String,
) -> Result<ClipboardEncryptedData, String> {
    let cipher = clipboard_cipher()?;
    let payload = cipher
        .encrypt_text(&item_id, &plaintext)
        .map_err(|error| format!("clipboard encryption failed: {error:?}"))?;
    Ok(ClipboardEncryptedData {
        nonce: payload.nonce.to_vec(),
        ciphertext: payload.ciphertext,
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn decrypt_clipboard_text(
    item_id: String,
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
) -> Result<String, String> {
    let nonce: [u8; CLIPBOARD_NONCE_LENGTH] = nonce
        .try_into()
        .map_err(|_| "invalid clipboard nonce".to_owned())?;
    clipboard_cipher()?
        .decrypt_text(&item_id, &EncryptedClipboardPayload { nonce, ciphertext })
        .map_err(|error| format!("clipboard decryption failed: {error:?}"))
}

pub fn watch_clipboard_text(sink: StreamSink<Option<String>>) -> Result<(), String> {
    watch(move |text| sink.add(text).is_ok())
}

#[cfg(windows)]
fn clipboard_cipher() -> Result<ClipboardCipher, String> {
    let key = islanddesk_platform_windows::WindowsClipboardKeyStore
        .load_or_create_key()
        .map_err(|error| format!("clipboard key unavailable: {error:?}"))?;
    ClipboardCipher::from_key(&key).map_err(|error| format!("clipboard cipher failed: {error:?}"))
}

#[cfg(not(windows))]
fn clipboard_cipher() -> Result<ClipboardCipher, String> {
    Err("secure clipboard storage is unavailable on this platform".into())
}

#[cfg(windows)]
fn watch(emit: impl FnMut(Option<String>) -> bool) -> Result<(), String> {
    islanddesk_platform_windows::WindowsClipboardListener.watch_text(emit)
}

#[cfg(not(windows))]
fn watch(mut emit: impl FnMut(Option<String>) -> bool) -> Result<(), String> {
    let _ = emit(None);
    Ok(())
}

#[cfg(windows)]
fn initialize() -> ClipboardSecurityStatus {
    use islanddesk_core::clipboard::{ClipboardCipher, ClipboardKeyStore};

    let result = islanddesk_platform_windows::WindowsClipboardKeyStore
        .load_or_create_key()
        .and_then(|key| {
            ClipboardCipher::from_key(&key)
                .map(|_| ())
                .map_err(|_| ClipboardKeyStoreError::Corrupt)
        });
    match result {
        Ok(()) => ClipboardSecurityStatus {
            supported: true,
            ready: true,
            backend: "windows_credential_manager".into(),
            error_code: None,
        },
        Err(error) => ClipboardSecurityStatus {
            supported: true,
            ready: false,
            backend: "windows_credential_manager".into(),
            error_code: Some(
                match error {
                    ClipboardKeyStoreError::Corrupt => "key_store_corrupt",
                    ClipboardKeyStoreError::Unavailable(_) => "key_store_unavailable",
                }
                .into(),
            ),
        },
    }
}

#[cfg(not(windows))]
fn initialize() -> ClipboardSecurityStatus {
    ClipboardSecurityStatus {
        supported: false,
        ready: false,
        backend: "unavailable".into(),
        error_code: None,
    }
}

#[cfg(test)]
mod tests {
    use super::clipboard_security_platform_supported;

    #[test]
    fn reports_clipboard_security_platform_support() {
        assert_eq!(clipboard_security_platform_supported(), cfg!(windows));
    }
}
