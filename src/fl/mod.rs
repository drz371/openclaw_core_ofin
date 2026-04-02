use crate::net::{ComplianceChecker, FlCoordinatorClient};
use anyhow::{Context, Result};
use std::path::Path;
use tracing::{debug, error, info, warn};

#[derive(Debug, Clone)]
pub struct FlConfig {
    pub max_upload_mb: usize,
}

#[derive(Debug)]
pub struct FlClient {
    agent_id: String,
    config: FlConfig,
    compliance: ComplianceChecker,
}

impl FlClient {
    pub fn new(agent_id: String, config: FlConfig, compliance: ComplianceChecker) -> Self {
        Self {
            agent_id,
            config,
            compliance,
        }
    }

    pub async fn upload_delta(&self, task_id: &str, file_path: &Path, coordinator_addr: &str) -> Result<()> {
        info!(
            agent_id = %self.agent_id,
            task_id = %task_id,
            file = %file_path.display(),
            event = "fl_upload_start",
            status = "started",
            "Starting delta upload"
        );

        self.compliance.check_fl_task(&self.agent_id, task_id)
            .context("Compliance check failed")?;

        let file_size = std::fs::metadata(file_path)
            .context("Failed to read file metadata")?
            .len();

        let max_size_bytes = (self.config.max_upload_mb * 1024 * 1024) as u64;
        if file_size > max_size_bytes {
            error!(
                agent_id = %self.agent_id,
                task_id = %task_id,
                file_size = %file_size,
                max_size = %max_size_bytes,
                event = "fl_upload_failed",
                status = "denied",
                reason = "SIZE-001",
                "File size exceeds maximum allowed"
            );
            return Err(anyhow::anyhow!("File size {} MB exceeds maximum allowed {} MB",
                file_size / (1024 * 1024), self.config.max_upload_mb));
        }

        let delta_data = std::fs::read(file_path)
            .context("Failed to read delta file")?;

        self.validate_delta_format(&delta_data)?;

        debug!(
            agent_id = %self.agent_id,
            task_id = %task_id,
            size_bytes = %delta_data.len(),
            event = "fl_upload_validating",
            status = "validating",
            "Delta data validated"
        );

        self.upload_to_coordinator(task_id, &delta_data, coordinator_addr).await?;

        info!(
            agent_id = %self.agent_id,
            task_id = %task_id,
            size_bytes = %delta_data.len(),
            event = "fl_upload_complete",
            status = "success",
            "Delta upload completed successfully"
        );

        Ok(())
    }

    fn validate_delta_format(&self, data: &[u8]) -> Result<()> {
        if data.is_empty() {
            return Err(anyhow::anyhow!("Delta data is empty"));
        }

        let magic_bytes = [0x4C, 0x6F, 0x52, 0x41];
        if data.len() >= 4 && &data[0..4] == magic_bytes {
            debug!("Detected LoRA format");
            return Ok(());
        }

        if data.len() >= 4 && &data[0..4] == [0x44, 0x45, 0x4C, 0x54] {
            debug!("Detected DELTA format");
            return Ok(());
        }

        warn!(
            agent_id = %self.agent_id,
            event = "fl_format_warning",
            status = "warning",
            "Unknown delta format, proceeding with caution"
        );

        Ok(())
    }

    async fn upload_to_coordinator(&self, task_id: &str, data: &[u8], coordinator_addr: &str) -> Result<()> {
        debug!(
            agent_id = %self.agent_id,
            task_id = %task_id,
            size_bytes = %data.len(),
            event = "fl_upload_to_coordinator",
            status = "uploading",
            "Uploading delta to coordinator"
        );

        let mut client = FlCoordinatorClient::connect(coordinator_addr.to_string())
            .await
            .context("Failed to connect to FL coordinator")?;

        let format = if data.len() >= 4 {
            match &data[0..4] {
                [0x4C, 0x6F, 0x52, 0x41] => "LoRA",
                [0x44, 0x45, 0x4C, 0x54] => "DELTA",
                _ => "UNKNOWN",
            }
        } else {
            "UNKNOWN"
        };

        let response = client
            .upload_delta(&self.agent_id, task_id, data.to_vec(), format)
            .await?;

        if response.success {
            info!(
                agent_id = %self.agent_id,
                task_id = %task_id,
                delta_id = %response.delta_id,
                event = "fl_upload_to_coordinator_success",
                status = "success",
                "Delta uploaded to coordinator successfully"
            );
        } else {
            warn!(
                agent_id = %self.agent_id,
                task_id = %task_id,
                message = %response.message,
                event = "fl_upload_to_coordinator_warning",
                status = "warning",
                "Coordinator returned warning"
            );
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::net::ComplianceConfig;
    use tempfile::NamedTempFile;

    fn create_test_client() -> FlClient {
        let compliance_config = ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        };
        let compliance = ComplianceChecker::new(compliance_config);
        let fl_config = FlConfig { max_upload_mb: 10 };
        FlClient::new("test_agent".to_string(), fl_config, compliance)
    }

    #[test]
    fn test_validate_lora_format() {
        let client = create_test_client();
        let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
        assert!(client.validate_delta_format(&lora_data).is_ok());
    }

    #[test]
    fn test_validate_delta_format() {
        let client = create_test_client();
        let delta_data = [0x44, 0x45, 0x4C, 0x54, 0x00, 0x01];
        assert!(client.validate_delta_format(&delta_data).is_ok());
    }

    #[test]
    fn test_validate_empty_data() {
        let client = create_test_client();
        assert!(client.validate_delta_format(&[]).is_err());
    }

    #[test]
    fn test_validate_unknown_format() {
        let client = create_test_client();
        let unknown_data = [0xFF, 0xFF, 0xFF, 0xFF];
        assert!(client.validate_delta_format(&unknown_data).is_ok());
    }

    #[tokio::test]
    async fn test_upload_delta_size_limit() {
        let client = create_test_client();
        let mut temp_file = NamedTempFile::new().unwrap();

        let large_data = vec![0u8; 11 * 1024 * 1024];
        std::fs::write(&temp_file, &large_data).unwrap();

        let result = client.upload_delta("grasping_v1", temp_file.path()).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("exceeds maximum allowed"));
    }

    #[tokio::test]
    async fn test_upload_delta_compliance_block() {
        let client = create_test_client();
        let mut temp_file = NamedTempFile::new().unwrap();

        let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
        std::fs::write(&temp_file, &lora_data).unwrap();

        let result = client.upload_delta("biometric_task", temp_file.path()).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Compliance"));
    }

    #[tokio::test]
    async fn test_upload_delta_success() {
        let client = create_test_client();
        let mut temp_file = NamedTempFile::new().unwrap();

        let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
        std::fs::write(&temp_file, &lora_data).unwrap();

        let result = client.upload_delta("grasping_v1", temp_file.path()).await;
        assert!(result.is_ok());
    }
}
