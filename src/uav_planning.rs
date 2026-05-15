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
    pub lat: f64,
    pub lon: f64,
    pub alt: f64,
    pub speed: f64,
    pub heading: f64,
    pub battery: f64,
    pub timestamp: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InspectionPoint {
    pub id: String,
    pub lat: f64,
    pub lon: f64,
    pub alt: f64,
    pub inspection_type: String,
    pub duration_seconds: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InspectionZone {
    pub name: String,
    pub center_lat: f64,
    pub center_lon: f64,
    pub width_meters: f64,
    pub height_meters: f64,
    pub altitude: f64,
    pub points: Vec<InspectionPoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Waypoint {
    pub lat: f64,
    pub lon: f64,
    pub alt: f64,
    pub speed: Option<f64>,
    pub action: Option<String>,
    pub hover_time_ms: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlightPath {
    pub path_id: String,
    pub waypoints: Vec<Waypoint>,
    pub total_distance_meters: f64,
    pub estimated_time_seconds: i64,
    pub battery_required_percent: f64,
    pub coverage_percent: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InspectionReport {
    pub inspection_id: String,
    pub zone_name: String,
    pub start_time: i64,
    pub end_time: i64,
    pub total_points: u32,
    pub completed_points: u32,
    pub findings: Vec<InspectionFinding>,
    pub recommendations: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InspectionFinding {
    pub point_id: String,
    pub severity: String,
    pub description: String,
    pub image_url: Option<String>,
}

pub fn generate_auto_patrol_path(
    start_pos: &UavPosition,
    zone: &InspectionZone,
    overlap_percent: f64,
) -> FlightPath {
    let mut waypoints = Vec::new();
    let mut total_distance = 0.0;

    let lat_step = calculate_lat_step(zone.width_meters, overlap_percent);
    let lon_step = calculate_lon_step(zone.height_meters, overlap_percent);

    let start_lat = zone.center_lat - (zone.width_meters / 2.0).to_radians() * 111000.0 / 111000.0;
    let start_lon = zone.center_lon - (zone.height_meters / 2.0).to_radians() * 111000.0 / 111000.0;

    let rows = ((zone.width_meters / lat_step) as u32).max(1);
    let cols = ((zone.height_meters / lon_step) as u32).max(1);

    let mut going_right = true;

    for row in 0..rows {
        if going_right {
            for col in 0..cols {
                let lat = start_lat + (row as f64) * lat_step;
                let lon = start_lon + (col as f64) * lon_step;

                let action = if row == 0 && col == 0 {
                    Some("takeoff".to_string())
                } else if row == rows - 1 && col == cols - 1 {
                    Some("return_home".to_string())
                } else {
                    Some("patrol".to_string())
                };

                waypoints.push(Waypoint {
                    lat,
                    lon,
                    alt: zone.altitude,
                    speed: Some(5.0),
                    action,
                    hover_time_ms: Some(500),
                });
            }
        } else {
            for col in (0..cols).rev() {
                let lat = start_lat + (row as f64) * lat_step;
                let lon = start_lon + (col as f64) * lon_step;

                waypoints.push(Waypoint {
                    lat,
                    lon,
                    alt: zone.altitude,
                    speed: Some(5.0),
                    action: Some("patrol".to_string()),
                    hover_time_ms: Some(500),
                });
            }
        }
        going_right = !going_right;
    }

    for i in 1..waypoints.len() {
        total_distance += haversine_distance(
            waypoints[i-1].lat, waypoints[i-1].lon,
            waypoints[i].lat, waypoints[i].lon,
        );
    }

    let avg_speed = 5.0;
    let estimated_time = (total_distance / avg_speed + waypoints.len() as f64 * 0.5) as i64;

    let battery_required = calculate_battery_consumption(total_distance, zone.altitude);

    FlightPath {
        path_id: format!("PATH-{}-{}", zone.name, current_timestamp()),
        waypoints,
        total_distance_meters: total_distance,
        estimated_time_seconds: estimated_time,
        battery_required_percent: battery_required,
        coverage_percent: (100.0 - overlap_percent).min(95.0),
    }
}

pub fn plan_industrial_inspection(
    uav_id: &str,
    facility_type: &str,
    zone: &InspectionZone,
) -> InspectionPlan {
    let path = generate_auto_patrol_path(
        &UavPosition {
            lat: zone.center_lat,
            lon: zone.center_lon,
            alt: 10.0,
        },
        zone,
        20.0,
    );

    let inspection_items: Vec<String> = match facility_type {
        "power_line" => vec![
            "导线检查".to_string(), "绝缘子检查".to_string(), "塔架检查".to_string(), "接地装置".to_string(),
        ],
        "solar_panel" => vec![
            "面板清洁度".to_string(), "热斑检测".to_string(), "支架稳定性".to_string(), "接线盒检查".to_string(),
        ],
        "wind_turbine" => vec![
            "叶片检查".to_string(), "齿轮箱".to_string(), "发电机".to_string(), "塔架腐蚀".to_string(),
        ],
        "pipeline" => vec![
            "泄漏检测".to_string(), "防腐层".to_string(), "支撑结构".to_string(), "阀门状态".to_string(),
        ],
        _ => vec![
            "设备外观".to_string(), "运行环境".to_string(), "安全标识".to_string(), "异常检测".to_string(),
        ],
    };

    let waypoints_for_points = path.waypoints.clone();
    let mut inspection_points: Vec<InspectionPoint> = Vec::new();
    for (i, wp) in waypoints_for_points.iter().enumerate() {
        if wp.action.as_deref() == Some("patrol") && i % 3 == 0 {
            inspection_points.push(InspectionPoint {
                id: format!("IP-{}", i),
                lat: wp.lat,
                lon: wp.lon,
                alt: wp.alt,
                inspection_type: inspection_items[i % inspection_items.len()].clone(),
                duration_seconds: 10,
            });
        }
    }

    let path_for_plan = FlightPath {
        path_id: path.path_id.clone(),
        waypoints: path.waypoints,
        total_distance_meters: path.total_distance_meters,
        estimated_time_seconds: path.estimated_time_seconds,
        battery_required_percent: path.battery_required_percent,
        coverage_percent: path.coverage_percent,
    };

    let inspection_points_len = inspection_points.len();

    InspectionPlan {
        plan_id: format!("INSP-{}-{}", uav_id, current_timestamp()),
        uav_id: uav_id.to_string(),
        facility_type: facility_type.to_string(),
        zone_name: zone.name.clone(),
        flight_path: path_for_plan,
        inspection_points,
        checklist: inspection_items,
        estimated_duration_seconds: path.estimated_time_seconds + (inspection_points_len as i64 * 15),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InspectionPlan {
    pub plan_id: String,
    pub uav_id: String,
    pub facility_type: String,
    pub zone_name: String,
    pub flight_path: FlightPath,
    pub inspection_points: Vec<InspectionPoint>,
    pub checklist: Vec<String>,
    pub estimated_duration_seconds: i64,
}

pub fn optimize_path_with_obstacles(
    start: &UavPosition,
    end: &UavPosition,
    obstacles: &[Obstacle],
    min_altitude: f64,
) -> FlightPath {
    let mut waypoints = vec![
        Waypoint {
            lat: start.lat,
            lon: start.lon,
            alt: start.alt.max(min_altitude),
            speed: Some(8.0),
            action: Some("takeoff".to_string()),
            hover_time_ms: None,
        }
    ];

    let mut current_pos = start.clone();
    let mut total_distance = 0.0;

    for obstacle in obstacles {
        if is_point_in_obstacle(&current_pos, obstacle) {
            let detour = calculate_detour_waypoint(&current_pos, obstacle);

            waypoints.push(Waypoint {
                lat: detour.lat,
                lon: detour.lon,
                alt: detour.alt.max(min_altitude + 30.0),
                speed: Some(5.0),
                action: Some("avoid_obstacle".to_string()),
                hover_time_ms: Some(200),
            });

            total_distance += haversine_distance(current_pos.lat, current_pos.lon, detour.lat, detour.lon);
            current_pos = detour;
        }
    }

    waypoints.push(Waypoint {
        lat: end.lat,
        lon: end.lon,
        alt: end.alt.max(min_altitude),
        speed: Some(8.0),
        action: Some("landing".to_string()),
        hover_time_ms: None,
    });

    total_distance += haversine_distance(current_pos.lat, current_pos.lon, end.lat, end.lon);

    let avg_altitude = (start.alt + end.alt) / 2.0 + 15.0;

    FlightPath {
        path_id: format!("OPT-{}-{}", current_timestamp() % 10000, current_timestamp()),
        waypoints,
        total_distance_meters: total_distance,
        estimated_time_seconds: (total_distance / 8.0) as i64,
        battery_required_percent: calculate_battery_consumption(total_distance, avg_altitude),
        coverage_percent: 100.0,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Obstacle {
    pub obstacle_type: String,
    pub lat: f64,
    pub lon: f64,
    pub radius_meters: f64,
    pub height_meters: f64,
}

fn calculate_lat_step(width_meters: f64, overlap: f64) -> f64 {
    let coverage = 1.0 - overlap / 100.0;
    let camera_fov_meters = 50.0;
    width_meters / (width_meters / (camera_fov_meters * coverage)).max(1.0)
}

fn calculate_lon_step(height_meters: f64, overlap: f64) -> f64 {
    let coverage = 1.0 - overlap / 100.0;
    let camera_fov_meters = 50.0;
    height_meters / (height_meters / (camera_fov_meters * coverage)).max(1.0)
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

fn calculate_battery_consumption(distance_meters: f64, avg_altitude: f64) -> f64 {
    let base_consumption = distance_meters / 100.0 * 0.5;
    let altitude_factor = 1.0 + (avg_altitude / 1000.0) * 0.2;
    let hover_consumption = distance_meters / 50.0 * 0.3;

    (base_consumption + hover_consumption) * altitude_factor
}

fn is_point_in_obstacle(pos: &UavPosition, obstacle: &Obstacle) -> bool {
    let distance = haversine_distance(pos.lat, pos.lon, obstacle.lat, obstacle.lon);
    distance < obstacle.radius_meters && pos.alt < obstacle.height_meters + 50.0
}

fn calculate_detour_waypoint(current: &UavPosition, obstacle: &Obstacle) -> UavPosition {
    let angle = ((obstacle.lat - current.lat).atan2(obstacle.lon - current.lon) + std::f64::consts::PI / 4.0);
    let distance = obstacle.radius_meters * 1.5;

    UavPosition {
        lat: current.lat + (angle.sin() * distance / 111000.0),
        lon: current.lon + (angle.cos() * distance / 111000.0),
        alt: obstacle.height_meters + 100.0,
    }
}

fn current_timestamp() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
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

    let health_score = (telemetry.battery / 100.0 * 70.0 + if telemetry.speed > 0.0 { 30.0 } else { 0.0 }).min(100.0);

    let mut warnings = Vec::new();
    if telemetry.battery < 20.0 {
        warnings.push("电池电量过低，建议立即返航".to_string());
    } else if telemetry.battery < 30.0 {
        warnings.push("电池电量偏低".to_string());
    }
    if telemetry.speed < 2.0 {
        warnings.push("飞行速度异常".to_string());
    }

    let mut recommendations = Vec::new();
    if telemetry.battery < 50.0 {
        recommendations.push("建议降低飞行速度以节省电量".to_string());
    }
    if telemetry.alt < 30.0 {
        recommendations.push("飞行高度较低，注意障碍物".to_string());
    }

    TelemetryAnalysis {
        uav_id: telemetry.uav_id.clone(),
        battery_status: battery_status.to_string(),
        speed_status: speed_status.to_string(),
        health_score,
        warnings,
        recommendations,
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
