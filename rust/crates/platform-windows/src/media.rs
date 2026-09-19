use std::sync::OnceLock;

use islanddesk_core::media::{
    MediaCapabilities, MediaCommand, MediaPlaybackState, MediaService, MediaServiceError,
    MediaSession,
};
use windows::Media::Control::{
    GlobalSystemMediaTransportControlsSession, GlobalSystemMediaTransportControlsSessionManager,
    GlobalSystemMediaTransportControlsSessionPlaybackStatus,
};
use windows::Win32::System::WinRT::{RO_INIT_MULTITHREADED, RoInitialize, RoUninitialize};

pub struct WindowsMediaService;

static SESSION_MANAGER: OnceLock<GlobalSystemMediaTransportControlsSessionManager> =
    OnceLock::new();

impl WindowsMediaService {
    fn current_windows_session(
        &self,
    ) -> Result<Option<GlobalSystemMediaTransportControlsSession>, MediaServiceError> {
        let manager = session_manager()?;
        let sessions = manager.GetSessions().map_err(platform_error)?;
        if sessions.Size().map_err(platform_error)? == 0 {
            return Ok(None);
        }

        Ok(Some(
            manager
                .GetCurrentSession()
                .or_else(|_| sessions.GetAt(0))
                .map_err(platform_error)?,
        ))
    }

    fn map_session(
        session: &GlobalSystemMediaTransportControlsSession,
    ) -> Result<MediaSession, MediaServiceError> {
        let properties = session
            .TryGetMediaPropertiesAsync()
            .and_then(|operation| operation.join())
            .map_err(platform_error)?;
        let playback = session.GetPlaybackInfo().map_err(platform_error)?;
        let controls = playback.Controls().map_err(platform_error)?;
        let timeline = session.GetTimelineProperties().map_err(platform_error)?;

        Ok(MediaSession {
            source_app_id: session
                .SourceAppUserModelId()
                .map_err(platform_error)?
                .to_string(),
            title: properties.Title().map_err(platform_error)?.to_string(),
            artist: properties.Artist().map_err(platform_error)?.to_string(),
            album_title: properties.AlbumTitle().map_err(platform_error)?.to_string(),
            playback_state: map_playback_state(playback.PlaybackStatus().map_err(platform_error)?),
            position_ms: ticks_to_millis(timeline.Position().map_err(platform_error)?.Duration),
            duration_ms: ticks_to_millis(timeline.EndTime().map_err(platform_error)?.Duration),
            capabilities: MediaCapabilities {
                can_play: controls.IsPlayEnabled().map_err(platform_error)?,
                can_pause: controls.IsPauseEnabled().map_err(platform_error)?,
                can_next: controls.IsNextEnabled().map_err(platform_error)?,
                can_previous: controls.IsPreviousEnabled().map_err(platform_error)?,
                can_seek: controls
                    .IsPlaybackPositionEnabled()
                    .map_err(platform_error)?,
            },
        })
    }
}

fn session_manager()
-> Result<&'static GlobalSystemMediaTransportControlsSessionManager, MediaServiceError> {
    if let Some(manager) = SESSION_MANAGER.get() {
        return Ok(manager);
    }

    let manager = GlobalSystemMediaTransportControlsSessionManager::RequestAsync()
        .and_then(|operation| operation.join())
        .map_err(platform_error)?;
    let _ = SESSION_MANAGER.set(manager);
    SESSION_MANAGER.get().ok_or_else(|| {
        MediaServiceError::Unavailable("session manager initialization failed".into())
    })
}

impl MediaService for WindowsMediaService {
    fn current_session(&self) -> Result<Option<MediaSession>, MediaServiceError> {
        let _apartment = Apartment::initialize()?;
        self.current_windows_session()?
            .as_ref()
            .map(Self::map_session)
            .transpose()
    }

    fn execute(&self, command: MediaCommand) -> Result<bool, MediaServiceError> {
        let _apartment = Apartment::initialize()?;
        let Some(session) = self.current_windows_session()? else {
            return Ok(false);
        };
        let operation = match command {
            MediaCommand::PlayPause => session.TryTogglePlayPauseAsync(),
            MediaCommand::Next => session.TrySkipNextAsync(),
            MediaCommand::Previous => session.TrySkipPreviousAsync(),
        }
        .map_err(platform_error)?;
        operation.join().map_err(platform_error)
    }
}

struct Apartment;

impl Apartment {
    fn initialize() -> Result<Self, MediaServiceError> {
        // The Windows adapter is the only layer that crosses the raw WinRT
        // apartment boundary. Every FRB worker thread initializes itself.
        unsafe { RoInitialize(RO_INIT_MULTITHREADED) }.map_err(platform_error)?;
        Ok(Self)
    }
}

impl Drop for Apartment {
    fn drop(&mut self) {
        unsafe { RoUninitialize() };
    }
}

fn map_playback_state(
    status: GlobalSystemMediaTransportControlsSessionPlaybackStatus,
) -> MediaPlaybackState {
    match status {
        GlobalSystemMediaTransportControlsSessionPlaybackStatus::Closed => {
            MediaPlaybackState::Closed
        }
        GlobalSystemMediaTransportControlsSessionPlaybackStatus::Opened => {
            MediaPlaybackState::Opened
        }
        GlobalSystemMediaTransportControlsSessionPlaybackStatus::Changing => {
            MediaPlaybackState::Changing
        }
        GlobalSystemMediaTransportControlsSessionPlaybackStatus::Stopped => {
            MediaPlaybackState::Stopped
        }
        GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing => {
            MediaPlaybackState::Playing
        }
        GlobalSystemMediaTransportControlsSessionPlaybackStatus::Paused => {
            MediaPlaybackState::Paused
        }
        _ => MediaPlaybackState::Unknown,
    }
}

fn ticks_to_millis(ticks: i64) -> u64 {
    ticks.max(0) as u64 / 10_000
}

fn platform_error(error: windows::core::Error) -> MediaServiceError {
    MediaServiceError::Platform(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::{map_playback_state, ticks_to_millis};
    use islanddesk_core::media::MediaPlaybackState;
    use windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus;

    #[test]
    fn converts_winrt_ticks_to_milliseconds_safely() {
        assert_eq!(ticks_to_millis(15_000_000), 1_500);
        assert_eq!(ticks_to_millis(-1), 0);
    }

    #[test]
    fn maps_windows_playback_states() {
        assert_eq!(
            map_playback_state(GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing),
            MediaPlaybackState::Playing
        );
        assert_eq!(
            map_playback_state(GlobalSystemMediaTransportControlsSessionPlaybackStatus::Paused),
            MediaPlaybackState::Paused
        );
    }
}
