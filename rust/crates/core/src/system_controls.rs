use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AudioEndpointState {
    pub available: bool,
    pub volume_percent: u8,
    pub muted: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AudioState {
    pub output: AudioEndpointState,
    pub input: AudioEndpointState,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SystemControlError {
    Unavailable(String),
    Platform(String),
}

impl Display for SystemControlError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unavailable(message) => {
                write!(formatter, "system controls unavailable: {message}")
            }
            Self::Platform(message) => write!(formatter, "system control error: {message}"),
        }
    }
}

impl std::error::Error for SystemControlError {}

pub trait AudioService {
    fn current_state(&self) -> Result<AudioState, SystemControlError>;

    fn set_output_volume(&self, volume_percent: u8) -> Result<(), SystemControlError>;

    fn set_output_muted(&self, muted: bool) -> Result<(), SystemControlError>;

    fn set_input_muted(&self, muted: bool) -> Result<(), SystemControlError>;
}

pub trait KeepAwakeService {
    fn is_active(&self) -> bool;

    fn set_active(&self, active: bool) -> Result<(), SystemControlError>;
}

#[cfg(test)]
mod tests {
    use super::{
        AudioEndpointState, AudioService, AudioState, KeepAwakeService, SystemControlError,
    };
    use std::cell::Cell;

    struct FakeAudioService {
        output_volume: Cell<u8>,
        output_muted: Cell<bool>,
        input_muted: Cell<bool>,
    }

    impl AudioService for FakeAudioService {
        fn current_state(&self) -> Result<AudioState, SystemControlError> {
            Ok(AudioState {
                output: AudioEndpointState {
                    available: true,
                    volume_percent: self.output_volume.get(),
                    muted: self.output_muted.get(),
                },
                input: AudioEndpointState {
                    available: true,
                    volume_percent: 100,
                    muted: self.input_muted.get(),
                },
            })
        }

        fn set_output_volume(&self, volume_percent: u8) -> Result<(), SystemControlError> {
            self.output_volume.set(volume_percent.min(100));
            Ok(())
        }

        fn set_output_muted(&self, muted: bool) -> Result<(), SystemControlError> {
            self.output_muted.set(muted);
            Ok(())
        }

        fn set_input_muted(&self, muted: bool) -> Result<(), SystemControlError> {
            self.input_muted.set(muted);
            Ok(())
        }
    }

    struct FakeKeepAwakeService(Cell<bool>);

    impl KeepAwakeService for FakeKeepAwakeService {
        fn is_active(&self) -> bool {
            self.0.get()
        }

        fn set_active(&self, active: bool) -> Result<(), SystemControlError> {
            self.0.set(active);
            Ok(())
        }
    }

    #[test]
    fn audio_contract_updates_output_and_mute_states() {
        let service = FakeAudioService {
            output_volume: Cell::new(35),
            output_muted: Cell::new(false),
            input_muted: Cell::new(false),
        };
        service.set_output_volume(72).unwrap();
        service.set_output_muted(true).unwrap();
        service.set_input_muted(true).unwrap();

        let state = service.current_state().unwrap();
        assert_eq!(state.output.volume_percent, 72);
        assert!(state.output.muted);
        assert!(state.input.muted);
    }

    #[test]
    fn keep_awake_contract_tracks_requested_state() {
        let service = FakeKeepAwakeService(Cell::new(false));
        service.set_active(true).unwrap();
        assert!(service.is_active());
        service.set_active(false).unwrap();
        assert!(!service.is_active());
    }
}
