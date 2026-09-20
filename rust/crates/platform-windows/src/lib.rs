#[cfg(windows)]
mod clipboard;
#[cfg(windows)]
mod fullscreen;
#[cfg(windows)]
mod media;
#[cfg(windows)]
mod system_controls;

#[cfg(windows)]
pub use clipboard::{WindowsClipboardCapture, WindowsClipboardKeyStore, WindowsClipboardListener};
#[cfg(windows)]
pub use fullscreen::WindowsFullscreenService;
#[cfg(windows)]
pub use media::WindowsMediaService;
#[cfg(windows)]
pub use system_controls::{WindowsAudioService, WindowsKeepAwakeService};
