use std::{
    sync::{OnceLock, mpsc},
    time::Duration,
};

use islanddesk_core::media::{
    MediaCapabilities, MediaCommand, MediaPlaybackState, MediaService, MediaServiceError,
    MediaSession,
};
use windows::Foundation::TypedEventHandler;
use windows::Media::Control::{
    GlobalSystemMediaTransportControlsSession, GlobalSystemMediaTransportControlsSessionManager,
    GlobalSystemMediaTransportControlsSessionMediaProperties,
    GlobalSystemMediaTransportControlsSessionPlaybackStatus,
};
use windows::Storage::Streams::DataReader;
use windows::Win32::System::WinRT::{RO_INIT_MULTITHREADED, RoInitialize, RoUninitialize};

pub struct WindowsMediaService;

const MAX_ARTWORK_BYTES: u64 = 8 * 1024 * 1024;

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
        let (artwork, artwork_content_type) = read_artwork(&properties)
            .unwrap_or(None)
            .unwrap_or_default();
        let source_app_id = session
            .SourceAppUserModelId()
            .map_err(platform_error)?
            .to_string();

        Ok(MediaSession {
            source_app_name: friendly_source_name(&source_app_id),
            source_app_id,
            title: properties.Title().map_err(platform_error)?.to_string(),
            artist: properties.Artist().map_err(platform_error)?.to_string(),
            album_title: properties.AlbumTitle().map_err(platform_error)?.to_string(),
            playback_state: map_playback_state(playback.PlaybackStatus().map_err(platform_error)?),
            position_ms: ticks_to_millis(timeline.Position().map_err(platform_error)?.Duration),
            duration_ms: ticks_to_millis(timeline.EndTime().map_err(platform_error)?.Duration),
            artwork,
            artwork_content_type,
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

    pub fn watch_current_session(
        &self,
        mut emit: impl FnMut(Option<MediaSession>) -> bool,
    ) -> Result<(), MediaServiceError> {
        let _apartment = Apartment::initialize()?;
        let manager = session_manager()?;
        let (sender, receiver) = mpsc::channel();
        let _manager_subscriptions = ManagerSubscriptions::new(manager, sender.clone())?;
        loop {
            let session = self.current_windows_session()?;
            let session_subscriptions = match session.as_ref() {
                Some(session) => Some(SessionSubscriptions::new(session, sender.clone())?),
                None => None,
            };
            let mapped = session.as_ref().map(Self::map_session).transpose()?;
            if !emit(mapped.clone()) {
                return Ok(());
            }

            loop {
                match receiver.recv_timeout(Duration::from_secs(2)) {
                    Ok(()) => break,
                    Err(mpsc::RecvTimeoutError::Timeout) => {
                        // A duplicate heartbeat lets a cancelled Dart stream release
                        // its WinRT event handlers even when the player is idle.
                        if !emit(mapped.clone()) {
                            return Ok(());
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Disconnected) => return Ok(()),
                }
            }

            drop(session_subscriptions);
        }
    }
}

struct ManagerSubscriptions<'a> {
    manager: &'a GlobalSystemMediaTransportControlsSessionManager,
    current_session_token: i64,
    sessions_token: i64,
}

impl<'a> ManagerSubscriptions<'a> {
    fn new(
        manager: &'a GlobalSystemMediaTransportControlsSessionManager,
        sender: mpsc::Sender<()>,
    ) -> Result<Self, MediaServiceError> {
        let current_sender = sender.clone();
        let current_session_token = manager
            .CurrentSessionChanged(&TypedEventHandler::new(move |_, _| {
                let _ = current_sender.send(());
                Ok(())
            }))
            .map_err(platform_error)?;
        let sessions_token = manager
            .SessionsChanged(&TypedEventHandler::new(move |_, _| {
                let _ = sender.send(());
                Ok(())
            }))
            .map_err(platform_error)?;
        Ok(Self {
            manager,
            current_session_token,
            sessions_token,
        })
    }
}

impl Drop for ManagerSubscriptions<'_> {
    fn drop(&mut self) {
        let _ = self
            .manager
            .RemoveCurrentSessionChanged(self.current_session_token);
        let _ = self.manager.RemoveSessionsChanged(self.sessions_token);
    }
}

struct SessionSubscriptions {
    session: GlobalSystemMediaTransportControlsSession,
    media_token: i64,
    playback_token: i64,
    timeline_token: i64,
}

impl SessionSubscriptions {
    fn new(
        session: &GlobalSystemMediaTransportControlsSession,
        sender: mpsc::Sender<()>,
    ) -> Result<Self, MediaServiceError> {
        let media_sender = sender.clone();
        let media_token = session
            .MediaPropertiesChanged(&TypedEventHandler::new(move |_, _| {
                let _ = media_sender.send(());
                Ok(())
            }))
            .map_err(platform_error)?;
        let playback_sender = sender.clone();
        let playback_token = session
            .PlaybackInfoChanged(&TypedEventHandler::new(move |_, _| {
                let _ = playback_sender.send(());
                Ok(())
            }))
            .map_err(platform_error)?;
        let timeline_token = session
            .TimelinePropertiesChanged(&TypedEventHandler::new(move |_, _| {
                let _ = sender.send(());
                Ok(())
            }))
            .map_err(platform_error)?;
        Ok(Self {
            session: session.clone(),
            media_token,
            playback_token,
            timeline_token,
        })
    }
}

impl Drop for SessionSubscriptions {
    fn drop(&mut self) {
        let _ = self.session.RemoveMediaPropertiesChanged(self.media_token);
        let _ = self.session.RemovePlaybackInfoChanged(self.playback_token);
        let _ = self
            .session
            .RemoveTimelinePropertiesChanged(self.timeline_token);
    }
}

fn read_artwork(
    properties: &GlobalSystemMediaTransportControlsSessionMediaProperties,
) -> Result<Option<(Vec<u8>, String)>, MediaServiceError> {
    let thumbnail = match properties.Thumbnail() {
        Ok(thumbnail) => thumbnail,
        Err(_) => return Ok(None),
    };
    let stream = match thumbnail
        .OpenReadAsync()
        .and_then(|operation| operation.join())
    {
        Ok(stream) => stream,
        Err(_) => return Ok(None),
    };
    let size = stream.Size().map_err(platform_error)?;
    if size == 0 || size > MAX_ARTWORK_BYTES || size > u32::MAX as u64 {
        return Ok(None);
    }
    let input = stream.GetInputStreamAt(0).map_err(platform_error)?;
    let reader = DataReader::CreateDataReader(&input).map_err(platform_error)?;
    reader
        .LoadAsync(size as u32)
        .and_then(|operation| operation.join())
        .map_err(platform_error)?;
    let mut bytes = vec![0; size as usize];
    reader.ReadBytes(&mut bytes).map_err(platform_error)?;
    Ok(Some((
        bytes,
        stream.ContentType().map_err(platform_error)?.to_string(),
    )))
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
            MediaCommand::Seek { position_ms } => {
                session.TryChangePlaybackPositionAsync(millis_to_ticks(position_ms))
            }
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

fn millis_to_ticks(milliseconds: u64) -> i64 {
    milliseconds.saturating_mul(10_000).min(i64::MAX as u64) as i64
}

fn friendly_source_name(source_app_id: &str) -> String {
    let path_leaf = source_app_id
        .rsplit(['\\', '/'])
        .next()
        .unwrap_or(source_app_id);
    let leaf = match path_leaf.rsplit_once('!') {
        Some((package, app)) if app.eq_ignore_ascii_case("app") => {
            package.split('_').next().unwrap_or(package)
        }
        Some((_, app)) => app,
        None => path_leaf,
    }
    .trim_end_matches(".exe");
    let words = leaf
        .split(['.', '_', '-'])
        .filter(|word| !word.is_empty())
        .map(|word| {
            let mut characters = word.chars();
            match characters.next() {
                Some(first) => first.to_uppercase().chain(characters).collect::<String>(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>();
    if words.is_empty() {
        source_app_id.to_owned()
    } else {
        words.join(" ")
    }
}

fn platform_error(error: windows::core::Error) -> MediaServiceError {
    MediaServiceError::Platform(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::{friendly_source_name, map_playback_state, millis_to_ticks, ticks_to_millis};
    use islanddesk_core::media::MediaPlaybackState;
    use windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus;

    #[test]
    fn converts_winrt_ticks_to_milliseconds_safely() {
        assert_eq!(ticks_to_millis(15_000_000), 1_500);
        assert_eq!(ticks_to_millis(-1), 0);
        assert_eq!(millis_to_ticks(1_500), 15_000_000);
        assert_eq!(millis_to_ticks(u64::MAX), i64::MAX);
    }

    #[test]
    fn creates_a_readable_source_name() {
        assert_eq!(friendly_source_name(r"C:\\Apps\\spotify.exe"), "Spotify");
        assert_eq!(
            friendly_source_name("Microsoft.ZuneMusic_8wekyb3d8bbwe!App"),
            "Microsoft ZuneMusic"
        );
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
