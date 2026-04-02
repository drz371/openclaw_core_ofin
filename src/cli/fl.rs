use anyhow::Result;
use clap::Subcommand;
use tracing::{error, info};

#[derive(Subcommand, Debug)]
pub enum FlCommands {
    #[command(name = "upload-delta")]
    UploadDelta {
        #[arg(long, help = "Task identifier (e.g., grasping_v1)")]
        task: String,

        #[arg(long, help = "Path to delta file (.lora or .delta)")]
        file: String,

        #[arg(long, default_value = "http://[::1]:50051", help = "Coordinator address")]
        coordinator: String,
    },
}

pub async fn handle_fl_commands(agent_id: String, commands: FlCommands) -> Result<()> {
    match commands {
        FlCommands::UploadDelta { task, file, coordinator } => {
            handle_upload_delta(agent_id, task, file, coordinator).await
        }
    }
}

async fn handle_upload_delta(agent_id: String, task_id: String, file_path: String, coordinator_addr: String) -> Result<()> {
    info!(
        agent_id = %agent_id,
        task_id = %task_id,
        file = %file_path,
        coordinator = %coordinator_addr,
        event = "fl_upload_command",
        status = "started",
        "Processing upload-delta command"
    );

    let path = std::path::Path::new(&file_path);
    if !path.exists() {
        error!(
            agent_id = %agent_id,
            file = %file_path,
            event = "fl_upload_failed",
            status = "error",
            reason = "FILE-NOT-FOUND",
            "Delta file does not exist"
        );
        return Err(anyhow::anyhow!("File not found: {}", file_path));
    }

    let config = crate::fl::FlConfig { max_upload_mb: 10 };
    let compliance = crate::net::ComplianceChecker::new(crate::net::ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });

    let client = crate::fl::FlClient::new(agent_id, config, compliance);

    match client.upload_delta(&task_id, path, &coordinator_addr).await {
        Ok(_) => {
            println!("✓ Delta uploaded successfully to task: {}", task_id);
            Ok(())
        }
        Err(e) => {
            error!(
                agent_id = %client.agent_id,
                task_id = %task_id,
                error = %e,
                event = "fl_upload_failed",
                status = "error",
                "Failed to upload delta"
            );
            Err(e)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[tokio::test]
    async fn test_upload_delta_command_success() {
        let mut temp_file = NamedTempFile::new().unwrap();
        let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
        std::fs::write(&temp_file, &lora_data).unwrap();

        let result = handle_upload_delta(
            "test_agent".to_string(),
            "grasping_v1".to_string(),
            temp_file.path().to_str().unwrap().to_string(),
            "http://[::1]:50051".to_string(),
        ).await;

        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_upload_delta_command_file_not_found() {
        let result = handle_upload_delta(
            "test_agent".to_string(),
            "grasping_v1".to_string(),
            "/nonexistent/file.lora".to_string(),
            "http://[::1]:50051".to_string(),
        ).await;

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("not found"));
    }

    #[tokio::test]
    async fn test_upload_delta_command_compliance_blocked() {
        let mut temp_file = NamedTempFile::new().unwrap();
        let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
        std::fs::write(&temp_file, &lora_data).unwrap();

        let result = handle_upload_delta(
            "test_agent".to_string(),
            "biometric_task".to_string(),
            temp_file.path().to_str().unwrap().to_string(),
            "http://[::1]:50051".to_string(),
        ).await;

        assert!(result.is_err());
    }
}
