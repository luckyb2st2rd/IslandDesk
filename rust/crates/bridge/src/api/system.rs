use flutter_rust_bridge::frb;

pub struct CoreStatus {
    pub name: String,
    pub version: String,
    pub target_os: String,
    pub target_arch: String,
}

#[frb(sync)]
pub fn get_core_status() -> CoreStatus {
    CoreStatus {
        name: "IslandDesk Core".to_owned(),
        version: env!("CARGO_PKG_VERSION").to_owned(),
        target_os: std::env::consts::OS.to_owned(),
        target_arch: std::env::consts::ARCH.to_owned(),
    }
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::get_core_status;

    #[test]
    fn reports_bridge_runtime_status() {
        let status = get_core_status();
        assert_eq!(status.name, "IslandDesk Core");
        assert_eq!(status.version, env!("CARGO_PKG_VERSION"));
        assert!(!status.target_os.is_empty());
        assert!(!status.target_arch.is_empty());
    }
}
