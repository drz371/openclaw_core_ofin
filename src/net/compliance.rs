use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use tracing::{error, info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceConfig {
    pub enabled: bool,
    pub country: String,
}

#[derive(Debug, Clone)]
pub struct ComplianceChecker {
    config: ComplianceConfig,
}

impl ComplianceChecker {
    pub fn new(config: ComplianceConfig) -> Self {
        Self { config }
    }

    pub fn check_skill_call(&self, agent_id: &str, skill_name: &str) -> Result<(), tonic::Status> {
        if !self.config.enabled {
            info!(
                agent_id = %agent_id,
                skill = %skill_name,
                event = "skill_called",
                status = "allowed",
                "Compliance check disabled"
            );
            return Ok(());
        }

        if self.config.country == "CN" {
            let blocked_patterns = ["face", "raw", "id_card", "generate"];
            let skill_lower = skill_name.to_lowercase();

            for pattern in blocked_patterns {
                if skill_lower.contains(pattern) {
                    error!(
                        agent_id = %agent_id,
                        skill = %skill_name,
                        event = "compliance_blocked",
                        status = "denied",
                        reason = "CN-DATA-001",
                        "Skill call blocked by compliance policy"
                    );
                    return Err(tonic::Status::permission_denied("CN-DATA-001"));
                }
            }
        }

        info!(
            agent_id = %agent_id,
            skill = %skill_name,
            event = "skill_called",
            status = "allowed",
            "Skill call passed compliance check"
        );
        Ok(())
    }

    pub fn check_fl_task(&self, agent_id: &str, task_id: &str) -> Result<(), tonic::Status> {
        if !self.config.enabled {
            info!(
                agent_id = %agent_id,
                task_id = %task_id,
                event = "fl_task_check",
                status = "allowed",
                "Compliance check disabled"
            );
            return Ok(());
        }

        if self.config.country == "CN" {
            let blocked_patterns = ["biometric", "portrait"];
            let task_lower = task_id.to_lowercase();

            for pattern in blocked_patterns {
                if task_lower.contains(pattern) {
                    error!(
                        agent_id = %agent_id,
                        task_id = %task_id,
                        event = "compliance_blocked",
                        status = "denied",
                        reason = "CN-DATA-001",
                        "FL task blocked by compliance policy"
                    );
                    return Err(tonic::Status::permission_denied("CN-DATA-001"));
                }
            }
        }

        info!(
            agent_id = %agent_id,
            task_id = %task_id,
            event = "fl_task_check",
            status = "allowed",
            "FL task passed compliance check"
        );
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_compliance_disabled() {
        let config = ComplianceConfig {
            enabled: false,
            country: "CN".to_string(),
        };
        let checker = ComplianceChecker::new(config);

        assert!(checker.check_skill_call("agent1", "face_detect").is_ok());
        assert!(checker.check_fl_task("agent1", "biometric_task").is_ok());
    }

    #[test]
    fn test_cn_skill_blocking() {
        let config = ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        };
        let checker = ComplianceChecker::new(config);

        assert!(checker.check_skill_call("agent1", "face_detect").is_err());
        assert!(checker.check_skill_call("agent1", "raw_data").is_err());
        assert!(checker.check_skill_call("agent1", "id_card_generate").is_err());
        assert!(checker.check_skill_call("agent1", "generate_id").is_err());
    }

    #[test]
    fn test_cn_fl_task_blocking() {
        let config = ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        };
        let checker = ComplianceChecker::new(config);

        assert!(checker.check_fl_task("agent1", "biometric_task").is_err());
        assert!(checker.check_fl_task("agent1", "portrait_recognition").is_err());
    }

    #[test]
    fn test_non_cn_allows_all() {
        let config = ComplianceConfig {
            enabled: true,
            country: "US".to_string(),
        };
        let checker = ComplianceChecker::new(config);

        assert!(checker.check_skill_call("agent1", "face_detect").is_ok());
        assert!(checker.check_fl_task("agent1", "biometric_task").is_ok());
    }

    #[test]
    fn test_safe_operations() {
        let config = ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        };
        let checker = ComplianceChecker::new(config);

        assert!(checker.check_skill_call("agent1", "summarize_pdf").is_ok());
        assert!(checker.check_skill_call("agent1", "detect_objects").is_ok());
        assert!(checker.check_fl_task("agent1", "grasping_v1").is_ok());
        assert!(checker.check_fl_task("agent1", "navigation_v2").is_ok());
    }
}
