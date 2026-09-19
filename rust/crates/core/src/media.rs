use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaPlaybackState {
    Closed,
    Opened,
    Changing,
    Stopped,
    Playing,
    Paused,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaCommand {
    PlayPause,
    Next,
    Previous,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MediaCapabilities {
    pub can_play: bool,
    pub can_pause: bool,
    pub can_next: bool,
    pub can_previous: bool,
    pub can_seek: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MediaServiceError {
    Unavailable(String),
    Platform(String),
}

impl Display for MediaServiceError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unavailable(message) => write!(formatter, "media service unavailable: {message}"),
            Self::Platform(message) => write!(formatter, "media service error: {message}"),
        }
    }
}

impl std::error::Error for MediaServiceError {}

pub trait MediaService {
    fn current_session(&self) -> Result<Option<MediaSession>, MediaServiceError>;

    fn execute(&self, command: MediaCommand) -> Result<bool, MediaServiceError>;
}

#[cfg(test)]
mod tests {
    use super::{
        MediaCapabilities, MediaCommand, MediaPlaybackState, MediaService, MediaServiceError,
        MediaSession,
    };

    struct FakeMediaService {
        session: Option<MediaSession>,
    }

    impl MediaService for FakeMediaService {
        fn current_session(&self) -> Result<Option<MediaSession>, MediaServiceError> {
            Ok(self.session.clone())
        }

        fn execute(&self, _command: MediaCommand) -> Result<bool, MediaServiceError> {
            Ok(self.session.is_some())
        }
    }

    #[test]
    fn media_service_contract_represents_session_and_empty_states() {
        let empty = FakeMediaService { session: None };
        assert_eq!(empty.current_session().unwrap(), None);
        assert!(!empty.execute(MediaCommand::PlayPause).unwrap());

        let expected = MediaSession {
            source_app_id: "test.player".to_owned(),
            title: "Test track".to_owned(),
            artist: "Test artist".to_owned(),
            album_title: "Test album".to_owned(),
            playback_state: MediaPlaybackState::Playing,
            position_ms: 1_000,
            duration_ms: 5_000,
            capabilities: MediaCapabilities {
                can_play: true,
                can_pause: true,
                can_next: true,
                can_previous: false,
                can_seek: true,
            },
        };
        let active = FakeMediaService {
            session: Some(expected.clone()),
        };

        assert_eq!(active.current_session().unwrap(), Some(expected));
        assert!(active.execute(MediaCommand::Next).unwrap());
    }
}
