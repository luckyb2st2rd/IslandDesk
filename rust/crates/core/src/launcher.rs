use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LaunchRequest {
    pub executable_path: String,
    pub arguments: Option<String>,
    pub working_directory: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LaunchServiceError {
    NotFound(String),
    Platform(String),
}

impl Display for LaunchServiceError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(path) => write!(formatter, "launch target not found: {path}"),
            Self::Platform(message) => write!(formatter, "application launch failed: {message}"),
        }
    }
}

impl std::error::Error for LaunchServiceError {}

pub trait LaunchService {
    fn launch(&self, request: &LaunchRequest) -> Result<(), LaunchServiceError>;
}

#[cfg(test)]
mod tests {
    use super::{LaunchRequest, LaunchService, LaunchServiceError};
    use std::cell::RefCell;

    #[derive(Default)]
    struct FakeLaunchService(RefCell<Option<LaunchRequest>>);

    impl LaunchService for FakeLaunchService {
        fn launch(&self, request: &LaunchRequest) -> Result<(), LaunchServiceError> {
            self.0.replace(Some(request.clone()));
            Ok(())
        }
    }

    #[test]
    fn launcher_contract_preserves_arguments_and_working_directory() {
        let service = FakeLaunchService::default();
        let request = LaunchRequest {
            executable_path: "C:\\Apps\\Editor.exe".into(),
            arguments: Some("--new-window".into()),
            working_directory: Some("C:\\Projects".into()),
        };

        service.launch(&request).unwrap();
        assert_eq!(service.0.borrow().as_ref(), Some(&request));
    }
}
