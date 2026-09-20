#[cfg(windows)]
use islanddesk_core::system_controls::{AudioService, KeepAwakeService};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioEndpointState {
    pub available: bool,
    pub volume_percent: u8,
    pub muted: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SystemControlsState {
    pub output: AudioEndpointState,
    pub input: AudioEndpointState,
    pub keep_awake: bool,
}

#[flutter_rust_bridge::frb(sync)]
pub fn system_controls_platform_supported() -> bool {
    cfg!(windows)
}

pub fn get_system_controls_state() -> Result<SystemControlsState, String> {
    current_state()
}

pub fn set_output_volume(volume_percent: u8) -> Result<SystemControlsState, String> {
    set_volume(volume_percent)
}

pub fn set_output_muted(muted: bool) -> Result<SystemControlsState, String> {
    set_output_mute(muted)
}

pub fn set_input_muted(muted: bool) -> Result<SystemControlsState, String> {
    set_input_mute(muted)
}

pub fn set_keep_awake(active: bool) -> Result<SystemControlsState, String> {
    set_awake(active)
}

#[cfg(windows)]
fn current_state() -> Result<SystemControlsState, String> {
    let audio = islanddesk_platform_windows::WindowsAudioService
        .current_state()
        .map_err(|error| error.to_string())?;
    Ok(SystemControlsState {
        output: AudioEndpointState {
            available: audio.output.available,
            volume_percent: audio.output.volume_percent,
            muted: audio.output.muted,
        },
        input: AudioEndpointState {
            available: audio.input.available,
            volume_percent: audio.input.volume_percent,
            muted: audio.input.muted,
        },
        keep_awake: islanddesk_platform_windows::WindowsKeepAwakeService.is_active(),
    })
}

#[cfg(not(windows))]
fn current_state() -> Result<SystemControlsState, String> {
    Err("system controls are only available on Windows".into())
}

#[cfg(windows)]
fn set_volume(volume_percent: u8) -> Result<SystemControlsState, String> {
    islanddesk_platform_windows::WindowsAudioService
        .set_output_volume(volume_percent)
        .map_err(|error| error.to_string())?;
    current_state()
}

#[cfg(not(windows))]
fn set_volume(_volume_percent: u8) -> Result<SystemControlsState, String> {
    current_state()
}

#[cfg(windows)]
fn set_output_mute(muted: bool) -> Result<SystemControlsState, String> {
    islanddesk_platform_windows::WindowsAudioService
        .set_output_muted(muted)
        .map_err(|error| error.to_string())?;
    current_state()
}

#[cfg(not(windows))]
fn set_output_mute(_muted: bool) -> Result<SystemControlsState, String> {
    current_state()
}

#[cfg(windows)]
fn set_input_mute(muted: bool) -> Result<SystemControlsState, String> {
    islanddesk_platform_windows::WindowsAudioService
        .set_input_muted(muted)
        .map_err(|error| error.to_string())?;
    current_state()
}

#[cfg(not(windows))]
fn set_input_mute(_muted: bool) -> Result<SystemControlsState, String> {
    current_state()
}

#[cfg(windows)]
fn set_awake(active: bool) -> Result<SystemControlsState, String> {
    islanddesk_platform_windows::WindowsKeepAwakeService
        .set_active(active)
        .map_err(|error| error.to_string())?;
    current_state()
}

#[cfg(not(windows))]
fn set_awake(_active: bool) -> Result<SystemControlsState, String> {
    current_state()
}

#[cfg(test)]
mod tests {
    use super::{AudioEndpointState, SystemControlsState};

    #[test]
    fn bridge_state_represents_audio_and_awake_status() {
        let state = SystemControlsState {
            output: AudioEndpointState {
                available: true,
                volume_percent: 65,
                muted: false,
            },
            input: AudioEndpointState {
                available: true,
                volume_percent: 80,
                muted: true,
            },
            keep_awake: true,
        };

        assert_eq!(state.output.volume_percent, 65);
        assert!(state.input.muted);
        assert!(state.keep_awake);
    }
}
