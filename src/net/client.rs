use crate::proto::clawfed::{
    agent_service_client::AgentServiceClient, fl_coordinator_client::FlCoordinatorClient as ProtoFlCoordinatorClient,
    AggregationRequest, AggregationResponse, AgentInfo, DiscoverRequest, DiscoverResponse,
    FlDeltaUpload, FlTaskListResponse, FlUploadResponse, GetAgentRequest, GetAgentResponse,
    GetModelRequest, GetModelResponse, RegisterRequest, RegisterResponse, SkillRequest, SkillResponse,
};
use std::time::Duration;
use tonic::transport::Channel;
use tracing::{debug, error, info};

pub struct AgentClient {
    client: AgentServiceClient<Channel>,
}

impl AgentClient {
    pub async fn connect(addr: String) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        info!(address = %addr, event = "client_connect", status = "connecting", "Connecting to agent");

        let channel = Channel::from_shared(addr)?
            .timeout(Duration::from_secs(30))
            .connect()
            .await?;

        info!(event = "client_connected", status = "success", "Connected to agent successfully");

        Ok(Self {
            client: AgentServiceClient::new(channel),
        })
    }

    pub async fn call_skill(
        &mut self,
        agent_id: &str,
        skill_name: &str,
        args_json: &str,
    ) -> Result<SkillResponse, tonic::Status> {
        let request_id = uuid::Uuid::new_v4().to_string();

        debug!(
            agent_id = %agent_id,
            skill = %skill_name,
            request_id = %request_id,
            event = "skill_call",
            status = "calling",
            "Calling remote skill"
        );

        let request = SkillRequest {
            agent_id: agent_id.to_string(),
            skill_name: skill_name.to_string(),
            args_json: args_json.to_string(),
            request_id,
        };

        let response = self.client.call_skill(request).await?.into_inner();

        debug!(
            agent_id = %agent_id,
            skill = %skill_name,
            success = %response.success,
            event = "skill_call_completed",
            status = "success",
            "Skill call completed"
        );

        Ok(response)
    }

    pub async fn register_agent(&mut self, agent_info: AgentInfo) -> Result<RegisterResponse, tonic::Status> {
        info!(
            agent_id = %agent_info.agent_id,
            event = "agent_register",
            status = "registering",
            "Registering agent"
        );

        let request = RegisterRequest {
            agent_info: Some(agent_info),
        };

        let response = self.client.register_agent(request).await?.into_inner();

        info!(
            event = "agent_registered",
            status = "success",
            "Agent registered successfully"
        );

        Ok(response)
    }

    pub async fn discover_agents(&mut self, skill_name: &str) -> Result<DiscoverResponse, tonic::Status> {
        debug!(
            skill = %skill_name,
            event = "agent_discovery",
            status = "discovering",
            "Discovering agents"
        );

        let request = DiscoverRequest {
            skill_name: skill_name.to_string(),
        };

        let response = self.client.discover_agents(request).await?.into_inner();

        debug!(
            skill = %skill_name,
            count = %response.agents.len(),
            event = "agent_discovery_completed",
            status = "success",
            "Agent discovery completed"
        );

        Ok(response)
    }

    pub async fn get_agent(&mut self, agent_id: &str) -> Result<GetAgentResponse, tonic::Status> {
        info!(
            agent_id = %agent_id,
            event = "get_agent",
            status = "requesting",
            "Getting agent info"
        );

        let request = GetAgentRequest {
            agent_id: agent_id.to_string(),
        };

        let response = self.client.get_agent(request).await?.into_inner();

        info!(
            agent_id = %agent_id,
            success = %response.success,
            event = "get_agent_completed",
            status = "success",
            "Get agent completed"
        );

        Ok(response)
    }
}

pub struct FlCoordinatorClientWrapper {
    client: ProtoFlCoordinatorClient<Channel>,
}

impl FlCoordinatorClientWrapper {
    pub async fn connect(addr: String) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        info!(address = %addr, event = "coordinator_connect", status = "connecting", "Connecting to FL coordinator");

        let uri = addr.parse::<tonic::transport::Uri>()?;
        let channel = Channel::builder(uri)
            .timeout(Duration::from_secs(30))
            .connect()
            .await?;

        info!(event = "coordinator_connected", status = "success", "Connected to coordinator successfully");

        Ok(Self {
            client: ProtoFlCoordinatorClient::new(channel),
        })
    }

    pub async fn upload_delta(
        &mut self,
        agent_id: &str,
        task_id: &str,
        delta_data: Vec<u8>,
        format: &str,
    ) -> Result<FlUploadResponse, tonic::Status> {
        info!(
            agent_id = %agent_id,
            task_id = %task_id,
            size_bytes = %delta_data.len(),
            format = %format,
            event = "fl_delta_upload",
            status = "uploading",
            "Uploading delta to coordinator"
        );

        let request = FlDeltaUpload {
            agent_id: agent_id.to_string(),
            task_id: task_id.to_string(),
            size_bytes: delta_data.len() as i64,
            delta_data,
            format: format.to_string(),
        };

        let response = self.client.upload_delta(request).await?.into_inner();

        info!(
            agent_id = %agent_id,
            task_id = %task_id,
            delta_id = %response.delta_id,
            event = "fl_delta_uploaded",
            status = "success",
            "Delta uploaded successfully"
        );

        Ok(response)
    }

    pub async fn list_tasks(&mut self) -> Result<FlTaskListResponse, tonic::Status> {
        debug!(event = "fl_task_list", status = "listing", "Listing FL tasks");

        let request = DiscoverRequest {
            skill_name: String::new(),
        };

        let response = self.client.list_tasks(request).await?.into_inner();

        debug!(
            count = %response.tasks.len(),
            event = "fl_task_list_completed",
            status = "success",
            "Task list completed"
        );

        Ok(response)
    }

    pub async fn trigger_aggregation(&mut self, task_id: &str) -> Result<AggregationResponse, tonic::Status> {
        info!(
            task_id = %task_id,
            event = "fl_aggregation_trigger",
            status = "triggering",
            "Triggering federated aggregation"
        );

        let request = AggregationRequest {
            task_id: task_id.to_string(),
        };

        let response = self.client.trigger_aggregation(request).await?.into_inner();

        info!(
            task_id = %task_id,
            delta_count = %response.delta_count,
            event = "fl_aggregation_completed",
            status = "success",
            "Federated aggregation completed"
        );

        Ok(response)
    }

    pub async fn get_aggregated_model(&mut self, task_id: &str) -> Result<GetModelResponse, tonic::Status> {
        info!(
            task_id = %task_id,
            event = "fl_model_get",
            status = "getting",
            "Getting aggregated model"
        );

        let request = GetModelRequest {
            task_id: task_id.to_string(),
        };

        let response = self.client.get_aggregated_model(request).await?.into_inner();

        info!(
            task_id = %task_id,
            size_bytes = %response.model_data.len(),
            event = "fl_model_retrieved",
            status = "success",
            "Aggregated model retrieved"
        );

        Ok(response)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_skill_request_creation() {
        let request = SkillRequest {
            agent_id: "agent1".to_string(),
            skill_name: "detect_objects".to_string(),
            args_json: r#"{"url": "test.jpg"}"#.to_string(),
            request_id: "req-123".to_string(),
        };

        assert_eq!(request.agent_id, "agent1");
        assert_eq!(request.skill_name, "detect_objects");
    }
}
