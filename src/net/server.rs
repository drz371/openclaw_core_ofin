use crate::net::compliance::ComplianceChecker;
use crate::proto::clawfed::{
    agent_service_server::{AgentService, AgentServiceServer},
    fl_coordinator_server::{FlCoordinator, FlCoordinatorServer},
    AgentInfo, DiscoverRequest, DiscoverResponse, FlDeltaUpload, FlTaskInfo,
    FlTaskListResponse, FlUploadResponse, RegisterRequest, RegisterResponse,
    SkillRequest, SkillResponse,
};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tonic::{transport::Server, Request, Response, Status};

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

        self.compliance
            .check_skill_call(&req.agent_id, &req.skill_name)?;

        let agent_info = self
            .registry
            .get_agent(&req.agent_id)
            .await
            .ok_or_else(|| Status::not_found(format!("Agent {} not found", req.agent_id)))?;

        if !agent_info.skills.contains(&req.skill_name) {
            return Err(Status::invalid_argument(format!(
                "Agent {} does not have skill {}",
                req.agent_id, req.skill_name
            )));
        }

        let result = process_skill_call(&req.skill_name, &req.args_json);

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
}

fn process_skill_call(skill_name: &str, args_json: &str) -> String {
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
        _ => serde_json::json!({"status": "processed", "args": args_json}).to_string(),
    }
}

pub struct FlCoordinatorImpl {
    registry: Arc<AgentRegistry>,
    compliance: Arc<ComplianceChecker>,
    tasks: Arc<RwLock<HashMap<String, FlTaskInfo>>>,
}

impl FlCoordinatorImpl {
    pub fn new(registry: Arc<AgentRegistry>, compliance: Arc<ComplianceChecker>) -> Self {
        Self {
            registry,
            compliance,
            tasks: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    async fn add_task(&self, task: FlTaskInfo) {
        let mut tasks = self.tasks.write().await;
        tasks.insert(task.task_id.clone(), task);
    }
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
