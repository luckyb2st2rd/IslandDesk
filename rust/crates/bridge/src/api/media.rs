use islanddesk_core::media::{
    MediaCapabilities as CoreCapabilities, MediaCommand, MediaPlaybackState as CorePlaybackState,
    MediaService, MediaSession as CoreSession,
};

pub enum MediaPlaybackState {
    Closed,
    Opened,
    Changing,
    Stopped,
    Playing,
    Paused,
    Unknown,
}

pub struct MediaCapabilities {
    pub can_play: bool,
    pub can_pause: bool,
    pub can_next: bool,
    pub can_previous: bool,
    pub can_seek: bool,
}

pub struct MediaSession {
    pub source_app_id: String,
    pub title: String,
    pub artist: String,
    pub album_title: String,
    pub playback_state: MediaPlaybackState,
    pub position_ms: u64,
    pub duration_ms: u64,
    pub capabilities: MediaCapabilities,
}

#[flutter_rust_bridge::frb(sync)]
pub fn media_platform_supported() -> bool {
    cfg!(windows)
}

pub fn get_current_media_session() -> Result<Option<MediaSession>, String> {
    current_session().map(|session| session.map(Into::into))
}

pub fn media_play_pause() -> Result<bool, String> {
    execute(MediaCommand::PlayPause)
}

pub fn media_next() -> Result<bool, String> {
    execute(MediaCommand::Next)
}

pub fn media_previous() -> Result<bool, String> {
    execute(MediaCommand::Previous)
}

#[cfg(windows)]
fn current_session() -> Result<Option<CoreSession>, String> {
    islanddesk_platform_windows::WindowsMediaService
        .current_session()
        .map_err(|error| error.to_string())
}

#[cfg(not(windows))]
fn current_session() -> Result<Option<CoreSession>, String> {
    Ok(None)
}

#[cfg(windows)]
fn execute(command: MediaCommand) -> Result<bool, String> {
    islanddesk_platform_windows::WindowsMediaService
        .execute(command)
        .map_err(|error| error.to_string())
}

#[cfg(not(windows))]
fn execute(_command: MediaCommand) -> Result<bool, String> {
    Ok(false)
}

impl From<CoreSession> for MediaSession {
    fn from(session: CoreSession) -> Self {
        Self {
            source_app_id: session.source_app_id,
            title: session.title,
            artist: session.artist,
            album_title: session.album_title,
            playback_state: session.playback_state.into(),
            position_ms: session.position_ms,
            duration_ms: session.duration_ms,
            capabilities: session.capabilities.into(),
        }
    }
}

impl From<CorePlaybackState> for MediaPlaybackState {
    fn from(state: CorePlaybackState) -> Self {
        match state {
            CorePlaybackState::Closed => Self::Closed,
            CorePlaybackState::Opened => Self::Opened,
            CorePlaybackState::Changing => Self::Changing,
            CorePlaybackState::Stopped => Self::Stopped,
            CorePlaybackState::Playing => Self::Playing,
            CorePlaybackState::Paused => Self::Paused,
            CorePlaybackState::Unknown => Self::Unknown,
        }
    }
}

impl From<CoreCapabilities> for MediaCapabilities {
    fn from(capabilities: CoreCapabilities) -> Self {
        Self {
            can_play: capabilities.can_play,
            can_pause: capabilities.can_pause,
            can_next: capabilities.can_next,
            can_previous: capabilities.can_previous,
            can_seek: capabilities.can_seek,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{MediaPlaybackState, MediaSession};
    use islanddesk_core::media::{
        MediaCapabilities, MediaPlaybackState as CorePlaybackState, MediaSession as CoreSession,
    };

    #[test]
    fn maps_core_media_session_to_bridge_model() {
        let session = MediaSession::from(CoreSession {
            source_app_id: "test.player".to_owned(),
            title: "Track".to_owned(),
            artist: "Artist".to_owned(),
            album_title: "Album".to_owned(),
            playback_state: CorePlaybackState::Playing,
            position_ms: 10,
            duration_ms: 20,
            capabilities: MediaCapabilities {
                can_play: true,
                can_pause: true,
                can_next: false,
                can_previous: false,
                can_seek: true,
            },
        });

        assert_eq!(session.title, "Track");
        assert!(matches!(
            session.playback_state,
            MediaPlaybackState::Playing
        ));
        assert!(session.capabilities.can_seek);
    }
}
