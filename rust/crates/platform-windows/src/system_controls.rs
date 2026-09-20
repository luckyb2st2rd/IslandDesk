use islanddesk_core::system_controls::{
    AudioEndpointState, AudioService, AudioState, KeepAwakeService, SystemControlError,
};
use std::{
    ptr,
    sync::{Mutex, OnceLock, mpsc},
    thread::{self, JoinHandle},
};
use windows::Win32::{
    Media::Audio::{
        EDataFlow, Endpoints::IAudioEndpointVolume, IMMDeviceEnumerator, MMDeviceEnumerator,
        eCapture, eMultimedia, eRender,
    },
    System::{
        Com::{CLSCTX_ALL, COINIT_MULTITHREADED, CoCreateInstance, CoInitializeEx, CoUninitialize},
        Power::{ES_CONTINUOUS, ES_DISPLAY_REQUIRED, ES_SYSTEM_REQUIRED, SetThreadExecutionState},
    },
};

pub struct WindowsAudioService;
pub struct WindowsKeepAwakeService;

struct KeepAwakeWorker {
    stop: mpsc::Sender<()>,
    thread: JoinHandle<()>,
}

struct ComApartment {
    initialized: bool,
}

impl ComApartment {
    fn initialize() -> Self {
        Self {
            initialized: unsafe { CoInitializeEx(None, COINIT_MULTITHREADED) }.is_ok(),
        }
    }
}

impl Drop for ComApartment {
    fn drop(&mut self) {
        if self.initialized {
            unsafe { CoUninitialize() };
        }
    }
}

static KEEP_AWAKE_WORKER: OnceLock<Mutex<Option<KeepAwakeWorker>>> = OnceLock::new();

impl AudioService for WindowsAudioService {
    fn current_state(&self) -> Result<AudioState, SystemControlError> {
        let _apartment = ComApartment::initialize();
        Ok(AudioState {
            output: read_endpoint_or_unavailable(eRender),
            input: read_endpoint_or_unavailable(eCapture),
        })
    }

    fn set_output_volume(&self, volume_percent: u8) -> Result<(), SystemControlError> {
        let _apartment = ComApartment::initialize();
        let endpoint = endpoint(eRender)?;
        unsafe {
            endpoint
                .SetMasterVolumeLevelScalar(f32::from(volume_percent.min(100)) / 100.0, ptr::null())
                .map_err(platform_error)
        }
    }

    fn set_output_muted(&self, muted: bool) -> Result<(), SystemControlError> {
        let _apartment = ComApartment::initialize();
        set_muted(eRender, muted)
    }

    fn set_input_muted(&self, muted: bool) -> Result<(), SystemControlError> {
        let _apartment = ComApartment::initialize();
        set_muted(eCapture, muted)
    }
}

impl KeepAwakeService for WindowsKeepAwakeService {
    fn is_active(&self) -> bool {
        KEEP_AWAKE_WORKER
            .get_or_init(|| Mutex::new(None))
            .lock()
            .is_ok_and(|worker| worker.is_some())
    }

    fn set_active(&self, active: bool) -> Result<(), SystemControlError> {
        let mut worker = KEEP_AWAKE_WORKER
            .get_or_init(|| Mutex::new(None))
            .lock()
            .map_err(|_| SystemControlError::Unavailable("keep-awake state lock failed".into()))?;
        if active == worker.is_some() {
            return Ok(());
        }
        if active {
            let (ready_tx, ready_rx) = mpsc::sync_channel(1);
            let (stop_tx, stop_rx) = mpsc::channel();
            let handle = thread::Builder::new()
                .name("islanddesk-keep-awake".into())
                .spawn(move || {
                    let result = set_execution_state(
                        ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED,
                    );
                    let is_active = result.is_ok();
                    let _ = ready_tx.send(result);
                    if is_active {
                        let _ = stop_rx.recv();
                        let _ = set_execution_state(ES_CONTINUOUS);
                    }
                })
                .map_err(|error| SystemControlError::Platform(error.to_string()))?;
            ready_rx.recv().map_err(|error| {
                SystemControlError::Platform(format!("keep-awake worker failed: {error}"))
            })??;
            *worker = Some(KeepAwakeWorker {
                stop: stop_tx,
                thread: handle,
            });
        } else if let Some(active_worker) = worker.take() {
            let _ = active_worker.stop.send(());
            active_worker
                .thread
                .join()
                .map_err(|_| SystemControlError::Platform("keep-awake worker panicked".into()))?;
        }
        Ok(())
    }
}

fn endpoint(flow: EDataFlow) -> Result<IAudioEndpointVolume, SystemControlError> {
    unsafe {
        let enumerator: IMMDeviceEnumerator =
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL).map_err(platform_error)?;
        let device = enumerator
            .GetDefaultAudioEndpoint(flow, eMultimedia)
            .map_err(platform_error)?;
        device.Activate(CLSCTX_ALL, None).map_err(platform_error)
    }
}

fn read_endpoint(
    endpoint: &IAudioEndpointVolume,
) -> Result<AudioEndpointState, SystemControlError> {
    unsafe {
        let volume = endpoint
            .GetMasterVolumeLevelScalar()
            .map_err(platform_error)?;
        let muted = endpoint.GetMute().map_err(platform_error)?.as_bool();
        Ok(AudioEndpointState {
            available: true,
            volume_percent: (volume.clamp(0.0, 1.0) * 100.0).round() as u8,
            muted,
        })
    }
}

fn read_endpoint_or_unavailable(flow: EDataFlow) -> AudioEndpointState {
    endpoint(flow)
        .and_then(|audio_endpoint| read_endpoint(&audio_endpoint))
        .unwrap_or(AudioEndpointState {
            available: false,
            volume_percent: 0,
            muted: false,
        })
}

fn set_muted(flow: EDataFlow, muted: bool) -> Result<(), SystemControlError> {
    let endpoint = endpoint(flow)?;
    unsafe { endpoint.SetMute(muted, ptr::null()).map_err(platform_error) }
}

fn set_execution_state(
    state: windows::Win32::System::Power::EXECUTION_STATE,
) -> Result<(), SystemControlError> {
    let previous = unsafe { SetThreadExecutionState(state) };
    if previous.0 == 0 {
        Err(SystemControlError::Platform(
            "SetThreadExecutionState returned zero".into(),
        ))
    } else {
        Ok(())
    }
}

fn platform_error(error: windows::core::Error) -> SystemControlError {
    SystemControlError::Platform(error.to_string())
}
