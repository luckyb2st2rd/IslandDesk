#[cfg(windows)]
mod media;

#[cfg(windows)]
pub use media::WindowsMediaService;
