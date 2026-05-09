use crate::net::{AgentClient, AgentRegistry, ComplianceChecker};
use crate::proto::clawfed::AgentInfo;
use anyhow::{Context, Result};
use std::collections::HashMap;
use tracing::{debug, error, info, warn};

pub struct Agent {
    pub id: String,
    pub address: String,
    pub port: u16,
    pub skills: Vec<String>,
    pub metadata: HashMap<String, String>,
}

impl Agent {
    pub fn new(id: String, address: String, port: u16) -> Self {
        Self {
            id,
            address,
            port,
            skills: Vec::new(),
            metadata: HashMap::new(),
        }
    }

    pub fn with_skills(mut self, skills: Vec<String>) -> Self {
        self.skills = skills;
        self
    }

    pub fn with_metadata(mut self, metadata: HashMap<String, String>) -> Self {
        self.metadata = metadata;
        self
    }

    pub fn to_agent_info(&self) -> AgentInfo {
        AgentInfo {
            agent_id: self.id.clone(),
            address: self.address.clone(),
            port: self.port as i32,
            skills: self.skills.clone(),
            metadata: self.metadata.clone(),
        }
    }
}

pub struct AgentManager {
    agent: Agent,
    registry: AgentRegistry,
    compliance: ComplianceChecker,
}

impl AgentManager {
    pub fn new(agent: Agent, registry: AgentRegistry, compliance: ComplianceChecker) -> Self {
        Self {
            agent,
            registry,
            compliance,
        }
    }

    pub async fn register_with_coordinator(&self, coordinator_addr: &str) -> Result<()> {
        info!(
            agent_id = %self.agent.id,
            coordinator = %coordinator_addr,
            event = "agent_register_start",
            status = "starting",
            "Registering agent with coordinator"
        );

        let mut client = AgentClient::connect(coordinator_addr.to_string())
            .await
            .map_err(|e| anyhow::anyhow!("Failed to connect to coordinator: {}", e))?;

        let agent_info = self.agent.to_agent_info();
        let response = client.register_agent(agent_info).await?;

        if response.success {
            info!(
                agent_id = %self.agent.id,
                event = "agent_register_success",
                status = "success",
                "Agent registered successfully"
            );
        } else {
            warn!(
                agent_id = %self.agent.id,
                message = %response.message,
                event = "agent_register_warning",
                status = "warning",
                "Agent registration returned warning"
            );
        }

        Ok(())
    }

    pub async fn discover_agents(&self, coordinator_addr: &str, skill_name: &str) -> Result<Vec<AgentInfo>> {
        debug!(
            agent_id = %self.agent.id,
            skill = %skill_name,
            event = "agent_discovery_start",
            status = "starting",
            "Discovering agents with skill"
        );

        let mut client = AgentClient::connect(coordinator_addr.to_string())
            .await
            .map_err(|e| anyhow::anyhow!("Failed to connect to coordinator: {}", e))?;

        let response = client.discover_agents(skill_name).await?;

        debug!(
            agent_id = %self.agent.id,
            skill = %skill_name,
            count = %response.agents.len(),
            event = "agent_discovery_complete",
            status = "success",
            "Agent discovery completed"
        );

        Ok(response.agents)
    }

    pub async fn call_remote_skill(
        &self,
        target_agent_id: &str,
        target_addr: &str,
        skill_name: &str,
        args_json: &str,
    ) -> Result<String> {
        info!(
            agent_id = %self.agent.id,
            target = %target_agent_id,
            skill = %skill_name,
            event = "remote_skill_call_start",
            status = "starting",
            "Calling remote skill"
        );

        self.compliance.check_skill_call(&self.agent.id, skill_name)?;

        let mut client = AgentClient::connect(target_addr.to_string())
            .await
            .map_err(|e| anyhow::anyhow!("Failed to connect to target agent: {}", e))?;

        let response = client.call_skill(target_agent_id, skill_name, args_json).await?;

        if response.success {
            info!(
                agent_id = %self.agent.id,
                target = %target_agent_id,
                skill = %skill_name,
                event = "remote_skill_call_success",
                status = "success",
                "Remote skill call completed"
            );
            Ok(response.result_json)
        } else {
            error!(
                agent_id = %self.agent.id,
                target = %target_agent_id,
                skill = %skill_name,
                error = %response.error_message,
                event = "remote_skill_call_failed",
                status = "error",
                "Remote skill call failed"
            );
            Err(anyhow::anyhow!("Skill call failed: {}", response.error_message))
        }
    }

    pub fn get_agent_info(&self) -> &Agent {
        &self.agent
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_agent_creation() {
        let agent = Agent::new("agent1".to_string(), "127.0.0.1".to_string(), 50051);
        assert_eq!(agent.id, "agent1");
        assert_eq!(agent.address, "127.0.0.1");
        assert_eq!(agent.port, 50051);
    }

    #[test]
    fn test_agent_with_skills() {
        let agent = Agent::new("agent1".to_string(), "127.0.0.1".to_string(), 50051)
            .with_skills(vec!["detect_objects".to_string(), "summarize_pdf".to_string()]);
        assert_eq!(agent.skills.len(), 2);
    }

    #[test]
    fn test_agent_to_agent_info() {
        let agent = Agent::new("agent1".to_string(), "127.0.0.1".to_string(), 50051)
            .with_skills(vec!["detect_objects".to_string()]);
        let info = agent.to_agent_info();
        assert_eq!(info.agent_id, "agent1");
        assert_eq!(info.skills.len(), 1);
    }
}
