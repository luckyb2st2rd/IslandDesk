#[cfg(windows)]
mod clipboard;
#[cfg(windows)]
mod fullscreen;
#[cfg(windows)]
mod hotkey;
#[cfg(windows)]
mod launcher;
#[cfg(windows)]
mod media;
#[cfg(windows)]
mod system_controls;

#[cfg(windows)]
pub use clipboard::{WindowsClipboardCapture, WindowsClipboardKeyStore, WindowsClipboardListener};
#[cfg(windows)]
pub use fullscreen::WindowsFullscreenService;
#[cfg(windows)]
pub use hotkey::{WindowsHotkeyEvent, WindowsHotkeyListener};
#[cfg(windows)]
pub use launcher::WindowsLaunchService;
#[cfg(windows)]
pub use media::WindowsMediaService;
#[cfg(windows)]
pub use system_controls::{WindowsAudioService, WindowsKeepAwakeService};
