use flutter_rust_bridge::frb;
use islanddesk_core::{MonitorMode as CoreMonitorMode, select_monitor};

pub enum MonitorMode {
    Primary,
    FollowActive,
    Fixed,
}

pub struct MonitorResolution {
    pub display_id: String,
    pub used_fallback: bool,
}

#[frb(sync)]
pub fn resolve_monitor(
    mode: MonitorMode,
    display_ids: Vec<String>,
    primary_id: String,
    active_id: Option<String>,
    fixed_id: Option<String>,
) -> Option<MonitorResolution> {
    let mode = match mode {
        MonitorMode::Primary => CoreMonitorMode::Primary,
        MonitorMode::FollowActive => CoreMonitorMode::FollowActive,
        MonitorMode::Fixed => CoreMonitorMode::Fixed,
    };

    select_monitor(
        mode,
        &display_ids,
        &primary_id,
        active_id.as_deref(),
        fixed_id.as_deref(),
    )
    .map(|selection| MonitorResolution {
        display_id: selection.display_id,
        used_fallback: selection.used_fallback,
    })
}
