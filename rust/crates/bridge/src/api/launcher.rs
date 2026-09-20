#[cfg(windows)]
use islanddesk_core::launcher::{LaunchRequest, LaunchService};

#[flutter_rust_bridge::frb(sync)]
pub fn launcher_platform_supported() -> bool {
    cfg!(windows)
}

pub fn launch_application(
    executable_path: String,
    arguments: Option<String>,
    working_directory: Option<String>,
) -> Result<bool, String> {
    launch(executable_path, arguments, working_directory)
}

#[cfg(windows)]
fn launch(
    executable_path: String,
    arguments: Option<String>,
    working_directory: Option<String>,
) -> Result<bool, String> {
    islanddesk_platform_windows::WindowsLaunchService
        .launch(&LaunchRequest {
            executable_path,
            arguments,
            working_directory,
        })
        .map(|()| true)
        .map_err(|error| error.to_string())
}

#[cfg(not(windows))]
fn launch(
    _executable_path: String,
    _arguments: Option<String>,
    _working_directory: Option<String>,
) -> Result<bool, String> {
    Err("application launching is not available on this platform".into())
}
