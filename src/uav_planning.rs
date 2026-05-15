use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UavPosition {
    pub lat: f64,
    pub lon: f64,
    pub alt: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UavTelemetry {
    pub uav_id: String,
    pub position: UavPosition,
    pub speed: f64,
    pub heading: f64,
    pub battery: f64,
    pub timestamp: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MissionTarget {
    pub lat: f64,
    pub lon: f64,
    pub alt: f64,
    pub action: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MissionConstraints {
    pub max_altitude: Option<f64>,
    pub max_speed: Option<f64>,
    pub no_fly_zones: Option<Vec<NoFlyZone>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoFlyZone {
    pub center_lat: f64,
    pub center_lon: f64,
    pub radius_meters: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Waypoint {
    pub lat: f64,
    pub lon: f64,
    pub alt: f64,
    pub speed: Option<f64>,
    pub action: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MissionPlan {
    pub mission_id: String,
    pub waypoints: Vec<Waypoint>,
    pub total_distance_meters: f64,
    pub estimated_time_seconds: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PathOptimizationRequest {
    pub start: UavPosition,
    pub end: UavPosition,
    pub obstacles: Option<Vec<Obstacle>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Obstacle {
    pub obstacle_type: String,
    pub lat: f64,
    pub lon: f64,
    pub radius_meters: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwarmTask {
    pub task_id: String,
    pub location: UavPosition,
    pub priority: u8,
    pub estimated_time: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwarmAllocation {
    pub task_id: String,
    pub assigned_uav: String,
    pub route: Vec<Waypoint>,
}

pub fn plan_mission(
    uav_id: &str,
    targets: &[MissionTarget],
    constraints: &Option<MissionConstraints>,
) -> MissionPlan {
    let mut waypoints = Vec::new();
    let mut total_distance = 0.0;

    for (i, target) in targets.iter().enumerate() {
        let speed = constraints
            .as_ref()
            .and_then(|c| c.max_speed)
            .unwrap_or(10.0);

        let wp = Waypoint {
            lat: target.lat,
            lon: target.lon,
            alt: target.alt,
            speed: Some(speed),
            action: target.action.clone(),
        };

        if i > 0 {
            let prev = &targets[i - 1];
            total_distance += haversine_distance(prev.lat, prev.lon, target.lat, target.lon);
        }

        waypoints.push(wp);
    }

    let avg_speed = constraints
        .as_ref()
        .and_then(|c| c.max_speed)
        .unwrap_or(10.0);
    let estimated_time = (total_distance / avg_speed) as i64;

    MissionPlan {
        mission_id: format!("M-{}-{}", uav_id, chrono_timestamp()),
        waypoints,
        total_distance_meters: total_distance,
        estimated_time_seconds: estimated_time,
    }
}

pub fn optimize_path(request: &PathOptimizationRequest) -> Vec<Waypoint> {
    let mut waypoints = Vec::new();

    waypoints.push(Waypoint {
        lat: request.start.lat,
        lon: request.start.lon,
        alt: request.start.alt,
        speed: Some(10.0),
        action: Some("takeoff".to_string()),
    });

    if let Some(obstacles) = &request.obstacles {
        for obstacle in obstacles {
            let detour_lat = obstacle.lat + 0.001;
            let detour_lon = obstacle.lon + 0.001;
            waypoints.push(Waypoint {
                lat: detour_lat,
                lon: detour_lon,
                alt: request.start.alt + 20.0,
                speed: Some(5.0),
                action: Some("detour".to_string()),
            });
        }
    }

    waypoints.push(Waypoint {
        lat: request.end.lat,
        lon: request.end.lon,
        alt: request.end.alt,
        speed: Some(10.0),
        action: Some("landing".to_string()),
    });

    waypoints
}

pub fn allocate_swarm_tasks(
    uavs: &[(String, f64)],
    tasks: &[SwarmTask],
) -> Vec<SwarmAllocation> {
    let mut allocations = Vec::new();
    let mut uav_tasks: HashMap<String, Vec<&SwarmTask>> = HashMap::new();

    for task in tasks.iter() {
        let available_uav = uavs
            .iter()
            .filter(|(_, battery)| *battery > 20.0)
            .min_by_key(|(_, battery)| (100 - *battery) as i32)
            .map(|(id, _)| id.clone());

        if let Some(uav_id) = available_uav {
            uav_tasks
                .entry(uav_id.clone())
                .or_default()
                .push(task);

            let route = vec![
                Waypoint {
                    lat: task.location.lat,
                    lon: task.location.lon,
                    alt: task.location.alt,
                    speed: Some(10.0),
                    action: Some("execute_task".to_string()),
                },
            ];

            allocations.push(SwarmAllocation {
                task_id: task.task_id.clone(),
                assigned_uav: uav_id,
                route,
            });
        }
    }

    allocations
}

pub fn analyze_telemetry(telemetry: &UavTelemetry) -> TelemetryAnalysis {
    let battery_status = if telemetry.battery > 50.0 {
        "healthy"
    } else if telemetry.battery > 20.0 {
        "warning"
    } else {
        "critical"
    };

    let speed_status = if telemetry.speed > 15.0 {
        "high"
    } else if telemetry.speed > 5.0 {
        "normal"
    } else {
        "low"
    };

    let health_score = calculate_health_score(telemetry);

    TelemetryAnalysis {
        uav_id: telemetry.uav_id.clone(),
        battery_status: battery_status.to_string(),
        speed_status: speed_status.to_string(),
        health_score,
        warnings: generate_warnings(telemetry),
        recommendations: generate_recommendations(telemetry),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelemetryAnalysis {
    pub uav_id: String,
    pub battery_status: String,
    pub speed_status: String,
    pub health_score: f64,
    pub warnings: Vec<String>,
    pub recommendations: Vec<String>,
}

fn calculate_health_score(telemetry: &UavTelemetry) -> f64 {
    let battery_score = telemetry.battery / 100.0;
    let speed_score = if telemetry.speed > 0.0 { 1.0 } else { 0.5 };
    (battery_score * 0.7 + speed_score * 0.3) * 100.0
}

fn generate_warnings(telemetry: &UavTelemetry) -> Vec<String> {
    let mut warnings = Vec::new();

    if telemetry.battery < 20.0 {
        warnings.push("电池电量过低，建议立即返航".to_string());
    } else if telemetry.battery < 30.0 {
        warnings.push("电池电量偏低".to_string());
    }

    if telemetry.speed < 2.0 {
        warnings.push("飞行速度异常".to_string());
    }

    warnings
}

fn generate_recommendations(telemetry: &UavTelemetry) -> Vec<String> {
    let mut recs = Vec::new();

    if telemetry.battery < 50.0 {
        recs.push("建议降低飞行速度以节省电量".to_string());
    }

    if telemetry.alt < 30.0 {
        recs.push("飞行高度较低，注意障碍物".to_string());
    }

    recs
}

fn haversine_distance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let r = 6371000.0;
    let d_lat = (lat2 - lat1).to_radians();
    let d_lon = (lon2 - lon1).to_radians();

    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (d_lon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();

    r * c
}

fn chrono_timestamp() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
}
