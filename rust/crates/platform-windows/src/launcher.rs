use islanddesk_core::launcher::{LaunchRequest, LaunchService, LaunchServiceError};
use std::path::Path;
use windows::{
    Win32::UI::{Shell::ShellExecuteW, WindowsAndMessaging::SW_SHOWNORMAL},
    core::HSTRING,
};

pub struct WindowsLaunchService;

impl LaunchService for WindowsLaunchService {
    fn launch(&self, request: &LaunchRequest) -> Result<(), LaunchServiceError> {
        if !Path::new(&request.executable_path).is_file() {
            return Err(LaunchServiceError::NotFound(
                request.executable_path.clone(),
            ));
        }
        let operation = HSTRING::from("open");
        let executable = HSTRING::from(&request.executable_path);
        let arguments = HSTRING::from(request.arguments.as_deref().unwrap_or_default());
        let working_directory =
            HSTRING::from(request.working_directory.as_deref().unwrap_or_default());
        let result = unsafe {
            ShellExecuteW(
                None,
                &operation,
                &executable,
                &arguments,
                &working_directory,
                SW_SHOWNORMAL,
            )
        };
        let status = result.0 as isize;
        if status > 32 {
            Ok(())
        } else {
            Err(LaunchServiceError::Platform(format!(
                "ShellExecuteW returned status {status}"
            )))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::WindowsLaunchService;
    use islanddesk_core::launcher::{LaunchRequest, LaunchService, LaunchServiceError};

    #[test]
    fn rejects_a_missing_application_without_calling_the_shell() {
        let result = WindowsLaunchService.launch(&LaunchRequest {
            executable_path: "Z:\\IslandDesk\\definitely-missing.exe".into(),
            arguments: None,
            working_directory: None,
        });

        assert!(matches!(result, Err(LaunchServiceError::NotFound(_))));
    }
}
