use crate::net::compliance::ComplianceChecker;
use crate::proto::clawfed::{
    agent_service_server::{AgentService, AgentServiceServer},
    fl_coordinator_server::{FlCoordinator, FlCoordinatorServer},
    AgentInfo, DiscoverRequest, DiscoverResponse, GetAgentRequest, GetAgentResponse,
    FlDeltaUpload, FlTaskInfo, FlTaskListResponse, FlUploadResponse, RegisterRequest, RegisterResponse,
    SkillRequest, SkillResponse,
};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tonic::{transport::Server, Request, Response, Status};

#[derive(Clone, Debug)]
struct DeltaInfo {
    agent_id: String,
    data: Vec<u8>,
    format: String,
    timestamp: u64,
}

pub struct AgentRegistry {
    agents: Arc<RwLock<HashMap<String, AgentInfo>>>,
}

impl AgentRegistry {
    pub fn new() -> Self {
        Self {
            agents: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn register(&self, agent_info: AgentInfo) -> Result<(), Status> {
        let mut agents = self.agents.write().await;
        agents.insert(agent_info.agent_id.clone(), agent_info);
        Ok(())
    }

    pub async fn discover(&self, skill_name: &str) -> Vec<AgentInfo> {
        let agents = self.agents.read().await;
        agents
            .values()
            .filter(|agent| agent.skills.contains(&skill_name.to_string()))
            .cloned()
            .collect()
    }

    pub async fn get_agent(&self, agent_id: &str) -> Option<AgentInfo> {
        let agents = self.agents.read().await;
        agents.get(agent_id).cloned()
    }
}

#[derive(Clone)]
pub struct AgentServiceImpl {
    registry: Arc<AgentRegistry>,
    compliance: Arc<ComplianceChecker>,
}

impl AgentServiceImpl {
    pub fn new(registry: Arc<AgentRegistry>, compliance: Arc<ComplianceChecker>) -> Self {
        Self {
            registry,
            compliance,
        }
    }
}

#[tonic::async_trait]
impl AgentService for AgentServiceImpl {
    async fn call_skill(
        &self,
        request: Request<SkillRequest>,
    ) -> Result<Response<SkillResponse>, Status> {
        let req = request.into_inner();

        tracing::info!(
            agent_id = %req.agent_id,
            skill = %req.skill_name,
            request_id = %req.request_id,
            event = "skill_call_received",
            status = "processing",
            "Received skill call request"
        );

        let agent_info = self
            .registry
            .get_agent(&req.agent_id)
            .await
            .ok_or_else(|| {
                tracing::error!(target_agent = %req.agent_id, event = "agent_not_found", "Target agent not found in registry");
                Status::not_found(format!("Agent {} not found", req.agent_id))
            })?;

        tracing::info!(
            agent_id = %req.agent_id,
            skills = ?agent_info.skills,
            requested_skill = %req.skill_name,
            event = "skill_check",
            "Checking skill availability"
        );

        if !agent_info.skills.contains(&req.skill_name) {
            return Err(Status::invalid_argument(format!(
                "Agent {} does not have skill {}",
                req.agent_id, req.skill_name
            )));
        }

        let result = process_skill_call(&req.skill_name, &req.args_json).await;

        tracing::info!(
            agent_id = %req.agent_id,
            skill = %req.skill_name,
            request_id = %req.request_id,
            event = "skill_call_completed",
            status = "success",
            "Skill call completed successfully"
        );

        Ok(Response::new(SkillResponse {
            success: true,
            result_json: result,
            error_message: String::new(),
            request_id: req.request_id,
        }))
    }

    async fn register_agent(
        &self,
        request: Request<RegisterRequest>,
    ) -> Result<Response<RegisterResponse>, Status> {
        let req = request.into_inner();
        let agent_info = req.agent_info.unwrap();

        tracing::info!(
            agent_id = %agent_info.agent_id,
            address = %agent_info.address,
            port = %agent_info.port,
            event = "agent_register",
            status = "registering",
            "Registering new agent"
        );

        self.registry.register(agent_info.clone()).await?;

        tracing::info!(
            agent_id = %agent_info.agent_id,
            event = "agent_registered",
            status = "success",
            "Agent registered successfully"
        );

        Ok(Response::new(RegisterResponse {
            success: true,
            message: format!("Agent {} registered successfully", agent_info.agent_id),
        }))
    }

    async fn discover_agents(
        &self,
        request: Request<DiscoverRequest>,
    ) -> Result<Response<DiscoverResponse>, Status> {
        let req = request.into_inner();

        tracing::info!(
            skill = %req.skill_name,
            event = "agent_discovery",
            status = "searching",
            "Discovering agents with skill"
        );

        let agents = self.registry.discover(&req.skill_name).await;

        tracing::info!(
            skill = %req.skill_name,
            count = %agents.len(),
            event = "agent_discovery_completed",
            status = "success",
            "Agent discovery completed"
        );

        Ok(Response::new(DiscoverResponse { agents }))
    }

    async fn get_agent(
        &self,
        request: Request<GetAgentRequest>,
    ) -> Result<Response<GetAgentResponse>, Status> {
        let req = request.into_inner();

        tracing::info!(
            agent_id = %req.agent_id,
            event = "get_agent",
            status = "searching",
            "Getting agent info"
        );

        match self.registry.get_agent(&req.agent_id).await {
            Some(agent_info) => {
                tracing::info!(
                    agent_id = %req.agent_id,
                    address = %agent_info.address,
                    event = "get_agent_found",
                    status = "success",
                    "Agent found"
                );
                Ok(Response::new(GetAgentResponse {
                    success: true,
                    agent: Some(agent_info),
                }))
            }
            None => {
                tracing::warn!(
                    agent_id = %req.agent_id,
                    event = "get_agent_not_found",
                    status = "not_found",
                    "Agent not found"
                );
                Err(Status::not_found(format!("Agent {} not found", req.agent_id)))
            }
        }
    }
}

async fn process_skill_call(skill_name: &str, args_json: &str) -> String {
    match skill_name {
        "detect_objects" => {
            serde_json::json!({
                "objects": [
                    {"class": "person", "confidence": 0.95},
                    {"class": "car", "confidence": 0.87}
                ],
                "count": 2
            })
            .to_string()
        }
        "summarize_pdf" => {
            serde_json::json!({
                "summary": "Document summary generated",
                "key_points": ["Point 1", "Point 2"],
                "word_count": 150
            })
            .to_string()
        }
        "process_data" => {
            serde_json::json!({
                "status": "processed",
                "records": 100,
                "processed": true
            })
            .to_string()
        }
        "analyze_context" => {
            crate::llm_integration::call_llm(skill_name, args_json).await
        }
        "generate_response" => {
            crate::llm_integration::call_llm(skill_name, args_json).await
        }
        "translate_text" => {
            crate::llm_integration::call_llm(skill_name, args_json).await
        }
        "auto_patrol" => {
            let request: Result<AutoPatrolRequest, _> = serde_json::from_str(args_json);
            match request {
                Ok(req) => {
                    let path = crate::uav_planning::generate_auto_patrol_path(
                        &crate::uav_planning::UavPosition {
                            lat: req.start_lat,
                            lon: req.start_lon,
                            alt: req.start_alt,
                        },
                        &crate::uav_planning::InspectionZone {
                            name: req.zone_name.clone(),
                            center_lat: req.zone_center_lat,
                            center_lon: req.zone_center_lon,
                            width_meters: req.zone_width,
                            height_meters: req.zone_height,
                            altitude: req.flight_altitude,
                            points: vec![],
                        },
                        req.overlap_percent,
                    );
                    serde_json::to_string(&path).unwrap_or_else(|_| r#"{"error":"serialization failed"}"#.to_string())
                }
                Err(_) => serde_json::json!({"status": "error", "message": "Invalid request format"}).to_string(),
            }
        }
        "industrial_inspection" => {
            let request: Result<InspectionRequest, _> = serde_json::from_str(args_json);
            match request {
                Ok(req) => {
                    let plan = crate::uav_planning::plan_industrial_inspection(
                        &req.uav_id,
                        &req.facility_type,
                        &crate::uav_planning::InspectionZone {
                            name: req.zone_name.clone(),
                            center_lat: req.zone_center_lat,
                            center_lon: req.zone_center_lon,
                            width_meters: req.zone_width,
                            height_meters: req.zone_height,
                            altitude: req.flight_altitude,
                            points: vec![],
                        },
                    );
                    serde_json::to_string(&plan).unwrap_or_else(|_| r#"{"error":"serialization failed"}"#.to_string())
                }
                Err(_) => serde_json::json!({"status": "error", "message": "Invalid request format"}).to_string(),
            }
        }
        "analyze_telemetry" => {
            let telemetry: Result<crate::uav_planning::UavTelemetry, _> = serde_json::from_str(args_json);
            match telemetry {
                Ok(t) => {
                    let analysis = crate::uav_planning::analyze_telemetry(&t);
                    serde_json::to_string(&analysis).unwrap_or_else(|_| r#"{"error":"serialization failed"}"#.to_string())
                }
                Err(_) => serde_json::json!({"status": "error", "message": "Invalid telemetry format"}).to_string(),
            }
        }
        _ => serde_json::json!({"status": "processed", "skill": skill_name, "args": args_json}).to_string(),
    }
}

#[derive(serde::Deserialize)]
struct AutoPatrolRequest {
    start_lat: f64,
    start_lon: f64,
    start_alt: f64,
    zone_name: String,
    zone_center_lat: f64,
    zone_center_lon: f64,
    zone_width: f64,
    zone_height: f64,
    flight_altitude: f64,
    overlap_percent: f64,
}

#[derive(serde::Deserialize)]
struct InspectionRequest {
    uav_id: String,
    zone_name: String,
    zone_center_lat: f64,
    zone_center_lon: f64,
    zone_width: f64,
    zone_height: f64,
    flight_altitude: f64,
    facility_type: String,
}

pub struct FlCoordinatorImpl {
    registry: Arc<AgentRegistry>,
    compliance: Arc<ComplianceChecker>,
    tasks: Arc<RwLock<HashMap<String, FlTaskInfo>>>,
    deltas: Arc<RwLock<HashMap<String, Vec<DeltaInfo>>>>,
    aggregated_models: Arc<RwLock<HashMap<String, Vec<u8>>>>,
}

impl FlCoordinatorImpl {
    pub fn new(registry: Arc<AgentRegistry>, compliance: Arc<ComplianceChecker>) -> Self {
        Self {
            registry,
            compliance,
            tasks: Arc::new(RwLock::new(HashMap::new())),
            deltas: Arc::new(RwLock::new(HashMap::new())),
            aggregated_models: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    async fn add_task(&self, task: FlTaskInfo) {
        let mut tasks = self.tasks.write().await;
        tasks.insert(task.task_id.clone(), task);
    }

    async fn store_delta(&self, task_id: &str, delta: DeltaInfo) {
        let mut deltas = self.deltas.write().await;
        deltas.entry(task_id.to_string())
            .or_insert_with(Vec::new)
            .push(delta);
    }

    async fn aggregate_deltas(&self, task_id: &str) -> Result<Vec<u8>, String> {
        let deltas = self.deltas.read().await;
        let task_deltas = deltas.get(task_id)
            .ok_or_else(|| format!("No deltas found for task {}", task_id))?;

        if task_deltas.is_empty() {
            return Err(format!("No deltas available for task {}", task_id));
        }

        let aggregated = federated_averaging(task_deltas);

        let mut models = self.aggregated_models.write().await;
        models.insert(task_id.to_string(), aggregated.clone());

        Ok(aggregated)
    }

    async fn get_aggregated_model(&self, task_id: &str) -> Option<Vec<u8>> {
        let models = self.aggregated_models.read().await;
        models.get(task_id).cloned()
    }
}

fn federated_averaging(deltas: &[DeltaInfo]) -> Vec<u8> {
    if deltas.is_empty() {
        return Vec::new();
    }

    if deltas.len() == 1 {
        return deltas[0].data.clone();
    }

    let total_len = deltas[0].data.len();
    let n = deltas.len();

    let mut sum: Vec<i64> = vec![0; total_len];

    for delta in deltas {
        for (i, &byte) in delta.data.iter().enumerate().take(total_len) {
            sum[i] += byte as i64;
        }
    }

    let weight = 1.0 / n as f64;
    sum.iter()
        .map(|&x| ((x as f64) * weight).round() as i8)
        .map(|x| x.max(i8::MIN).min(i8::MAX) as u8)
        .collect()
}

#[tonic::async_trait]
impl FlCoordinator for FlCoordinatorImpl {
    async fn upload_delta(
        &self,
        request: Request<FlDeltaUpload>,
    ) -> Result<Response<FlUploadResponse>, Status> {
        let req = request.into_inner();

        tracing::info!(
            agent_id = %req.agent_id,
            task_id = %req.task_id,
            size_bytes = %req.size_bytes,
            format = %req.format,
            event = "fl_delta_upload",
            status = "processing",
            "Received delta upload"
        );

        self.compliance.check_fl_task(&req.agent_id, &req.task_id)?;

        let delta_id = format!("{}-{}", req.task_id, uuid::Uuid::new_v4());

        let delta_info = DeltaInfo {
            agent_id: req.agent_id.clone(),
            data: req.delta_data.clone(),
            format: req.format.clone(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        };

        self.store_delta(&req.task_id, delta_info).await;

        tracing::info!(
            agent_id = %req.agent_id,
            task_id = %req.task_id,
            delta_id = %delta_id,
            event = "fl_delta_uploaded",
            status = "success",
            "Delta uploaded successfully"
        );

        Ok(Response::new(FlUploadResponse {
            success: true,
            message: format!("Delta uploaded successfully: {}", delta_id),
            delta_id,
        }))
    }

    async fn list_tasks(
        &self,
        _request: Request<DiscoverRequest>,
    ) -> Result<Response<FlTaskListResponse>, Status> {
        let tasks = self.tasks.read().await;
        let task_list: Vec<FlTaskInfo> = tasks.values().cloned().collect();

        Ok(Response::new(FlTaskListResponse { tasks: task_list }))
    }

    async fn trigger_aggregation(
        &self,
        request: Request<crate::proto::clawfed::AggregationRequest>,
    ) -> Result<Response<crate::proto::clawfed::AggregationResponse>, Status> {
        let req = request.into_inner();

        tracing::info!(
            task_id = %req.task_id,
            event = "fl_aggregation_triggered",
            status = "starting",
            "Triggering federated aggregation"
        );

        match self.aggregate_deltas(&req.task_id).await {
            Ok(_) => {
                let deltas = self.deltas.read().await;
                let count = deltas.get(&req.task_id).map(|d| d.len()).unwrap_or(0) as i32;

                tracing::info!(
                    task_id = %req.task_id,
                    delta_count = %count,
                    event = "fl_aggregation_complete",
                    status = "success",
                    "Federated aggregation completed"
                );

                Ok(Response::new(crate::proto::clawfed::AggregationResponse {
                    success: true,
                    message: format!("Aggregation completed with {} deltas", count),
                    task_id: req.task_id,
                    delta_count: count,
                }))
            }
            Err(e) => {
                tracing::error!(
                    task_id = %req.task_id,
                    error = %e,
                    event = "fl_aggregation_failed",
                    status = "error",
                    "Federated aggregation failed"
                );
                Err(Status::internal(e))
            }
        }
    }

    async fn get_aggregated_model(
        &self,
        request: Request<crate::proto::clawfed::GetModelRequest>,
    ) -> Result<Response<crate::proto::clawfed::GetModelResponse>, Status> {
        let req = request.into_inner();

        match self.get_aggregated_model(&req.task_id).await {
            Some(data) => {
                tracing::info!(
                    task_id = %req.task_id,
                    size_bytes = %data.len(),
                    event = "fl_model_retrieved",
                    status = "success",
                    "Aggregated model retrieved"
                );
                Ok(Response::new(crate::proto::clawfed::GetModelResponse {
                    success: true,
                    model_data: data,
                    task_id: req.task_id,
                }))
            }
            None => Err(Status::not_found(format!(
                "Aggregated model not found for task {}",
                req.task_id
            ))),
        }
    }
}

pub async fn start_server(
    addr: String,
    registry: Arc<AgentRegistry>,
    compliance: Arc<ComplianceChecker>,
) -> Result<(), Box<dyn std::error::Error>> {
    let agent_service = AgentServiceImpl::new(registry.clone(), compliance.clone());
    let fl_coordinator = FlCoordinatorImpl::new(registry, compliance);

    let addr = addr.parse()?;

    tracing::info!(address = %addr, event = "server_start", status = "starting", "Starting gRPC server");

    Server::builder()
        .add_service(AgentServiceServer::new(agent_service))
        .add_service(FlCoordinatorServer::new(fl_coordinator))
        .serve(addr)
        .await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::net::compliance::ComplianceConfig;

    #[tokio::test]
    async fn test_agent_registry() {
        let registry = AgentRegistry::new();

        let agent_info = AgentInfo {
            agent_id: "agent1".to_string(),
            address: "127.0.0.1".to_string(),
            port: 50051,
            skills: vec!["detect_objects".to_string()],
            metadata: HashMap::new(),
        };

        registry.register(agent_info.clone()).await.unwrap();

        let retrieved = registry.get_agent("agent1").await;
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().agent_id, "agent1");
    }

    #[tokio::test]
    async fn test_agent_discovery() {
        let registry = AgentRegistry::new();

        let agent_info = AgentInfo {
            agent_id: "agent1".to_string(),
            address: "127.0.0.1".to_string(),
            port: 50051,
            skills: vec!["detect_objects".to_string(), "summarize_pdf".to_string()],
            metadata: HashMap::new(),
        };

        registry.register(agent_info).await.unwrap();

        let agents = registry.discover("detect_objects").await;
        assert_eq!(agents.len(), 1);
        assert_eq!(agents[0].agent_id, "agent1");
    }
}
