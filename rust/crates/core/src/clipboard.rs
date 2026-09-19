//! Privacy-preserving clipboard domain primitives.

use aes_gcm::{
    Aes256Gcm, Key, Nonce,
    aead::{Aead, Generate, KeyInit, Payload},
};

pub const CLIPBOARD_KEY_LENGTH: usize = 32;
pub const CLIPBOARD_NONCE_LENGTH: usize = 12;
const CLIPBOARD_AAD_PREFIX: &[u8] = b"islanddesk.clipboard.v1\0";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EncryptedClipboardPayload {
    pub nonce: [u8; CLIPBOARD_NONCE_LENGTH],
    pub ciphertext: Vec<u8>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ClipboardCryptoError {
    InvalidKeyLength,
    EncryptionFailed,
    AuthenticationFailed,
    InvalidUtf8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClipboardKeyStoreError {
    Unavailable(String),
    Corrupt,
}

pub trait ClipboardKeyStore {
    fn load_or_create_key(&self) -> Result<[u8; CLIPBOARD_KEY_LENGTH], ClipboardKeyStoreError>;
}

pub struct ClipboardCipher {
    cipher: Aes256Gcm,
}

impl ClipboardCipher {
    pub fn from_key(key: &[u8]) -> Result<Self, ClipboardCryptoError> {
        let key =
            Key::<Aes256Gcm>::try_from(key).map_err(|_| ClipboardCryptoError::InvalidKeyLength)?;
        Ok(Self {
            cipher: Aes256Gcm::new(&key),
        })
    }

    pub fn generate_key() -> [u8; CLIPBOARD_KEY_LENGTH] {
        Key::<Aes256Gcm>::generate().into()
    }

    pub fn encrypt_text(
        &self,
        item_id: &str,
        plaintext: &str,
    ) -> Result<EncryptedClipboardPayload, ClipboardCryptoError> {
        let nonce = Nonce::generate();
        let ciphertext = self
            .cipher
            .encrypt(
                &nonce,
                Payload {
                    msg: plaintext.as_bytes(),
                    aad: &associated_data(item_id),
                },
            )
            .map_err(|_| ClipboardCryptoError::EncryptionFailed)?;
        Ok(EncryptedClipboardPayload {
            nonce: nonce.into(),
            ciphertext,
        })
    }

    pub fn decrypt_text(
        &self,
        item_id: &str,
        payload: &EncryptedClipboardPayload,
    ) -> Result<String, ClipboardCryptoError> {
        let nonce = Nonce::from(payload.nonce);
        let plaintext = self
            .cipher
            .decrypt(
                &nonce,
                Payload {
                    msg: &payload.ciphertext,
                    aad: &associated_data(item_id),
                },
            )
            .map_err(|_| ClipboardCryptoError::AuthenticationFailed)?;
        String::from_utf8(plaintext).map_err(|_| ClipboardCryptoError::InvalidUtf8)
    }
}

fn associated_data(item_id: &str) -> Vec<u8> {
    let mut aad = Vec::with_capacity(CLIPBOARD_AAD_PREFIX.len() + item_id.len());
    aad.extend_from_slice(CLIPBOARD_AAD_PREFIX);
    aad.extend_from_slice(item_id.as_bytes());
    aad
}

#[cfg(test)]
mod tests {
    use super::{ClipboardCipher, ClipboardCryptoError};

    #[test]
    fn encrypts_and_authenticates_clipboard_text() {
        let cipher = ClipboardCipher::from_key(&[7; 32]).unwrap();
        let encrypted = cipher.encrypt_text("item-1", "private clipboard").unwrap();

        assert_ne!(encrypted.ciphertext, b"private clipboard");
        assert_eq!(
            cipher.decrypt_text("item-1", &encrypted).unwrap(),
            "private clipboard"
        );
        assert_eq!(
            cipher.decrypt_text("other-item", &encrypted),
            Err(ClipboardCryptoError::AuthenticationFailed)
        );
    }

    #[test]
    fn uses_a_unique_nonce_and_rejects_tampering() {
        let cipher = ClipboardCipher::from_key(&[9; 32]).unwrap();
        let first = cipher.encrypt_text("item", "same text").unwrap();
        let second = cipher.encrypt_text("item", "same text").unwrap();

        assert_ne!(first.nonce, second.nonce);
        assert_ne!(first.ciphertext, second.ciphertext);

        let mut tampered = first;
        tampered.ciphertext[0] ^= 1;
        assert_eq!(
            cipher.decrypt_text("item", &tampered),
            Err(ClipboardCryptoError::AuthenticationFailed)
        );
    }

    #[test]
    fn rejects_keys_that_are_not_256_bits() {
        assert!(matches!(
            ClipboardCipher::from_key(&[0; 16]),
            Err(ClipboardCryptoError::InvalidKeyLength)
        ));
    }
}
