use islanddesk_core::clipboard::ClipboardKeyStoreError;

pub struct ClipboardSecurityStatus {
    pub supported: bool,
    pub ready: bool,
    pub backend: String,
    pub error_code: Option<String>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn clipboard_security_platform_supported() -> bool {
    cfg!(windows)
}

#[flutter_rust_bridge::frb(sync)]
pub fn initialize_clipboard_security() -> ClipboardSecurityStatus {
    initialize()
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
