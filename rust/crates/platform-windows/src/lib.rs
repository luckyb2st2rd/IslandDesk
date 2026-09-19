#[cfg(windows)]
mod clipboard;
#[cfg(windows)]
mod fullscreen;
#[cfg(windows)]
mod media;

#[cfg(windows)]
pub use clipboard::{WindowsClipboardKeyStore, WindowsClipboardListener};
#[cfg(windows)]
pub use fullscreen::WindowsFullscreenService;
#[cfg(windows)]
pub use media::WindowsMediaService;
