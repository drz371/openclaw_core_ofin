use clawfed::cli::Cli;
use tempfile::NamedTempFile;
use std::path::Path;

#[test]
fn test_cli_parsing_agent() {
    let cli = Cli::try_parse_from(["clawfed", "agent", "--config", "./test.toml"]);
    assert!(cli.is_ok());
    let cli = cli.unwrap();
    assert_eq!(cli.log_level, None);
    assert_eq!(cli.log_format, None);
}

#[test]
fn test_cli_parsing_call() {
    let cli = Cli::try_parse_from([
        "clawfed",
        "call",
        "vision_agent_01",
        "detect_objects",
        "--args",
        r#"{"url": "https://example.com/image.jpg"}"#,
    ]);
    assert!(cli.is_ok());
}

#[test]
fn test_cli_parsing_fl_upload() {
    let cli = Cli::try_parse_from([
        "clawfed",
        "fl",
        "upload-delta",
        "--task",
        "grasping_v1",
        "--file",
        "delta.lora",
    ]);
    assert!(cli.is_ok());
}

#[test]
fn test_cli_parsing_with_logging() {
    let cli = Cli::try_parse_from([
        "clawfed",
        "agent",
        "--config",
        "./test.toml",
        "--log-level",
        "debug",
        "--log-format",
        "json",
    ]);
    assert!(cli.is_ok());
    let cli = cli.unwrap();
    assert_eq!(cli.log_level, Some("debug".to_string()));
    assert_eq!(cli.log_format, Some("json".to_string()));
}

#[test]
fn test_cli_invalid_command() {
    let cli = Cli::try_parse_from(["clawfed", "invalid"]);
    assert!(cli.is_err());
}

#[test]
fn test_compliance_skill_blocking() {
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let config = ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    };
    let checker = ComplianceChecker::new(config);

    assert!(checker.check_skill_call("agent1", "face_detect").is_err());
    assert!(checker.check_skill_call("agent1", "raw_data").is_err());
    assert!(checker.check_skill_call("agent1", "id_card_generate").is_err());
}

#[test]
fn test_compliance_skill_allowed() {
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let config = ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    };
    let checker = ComplianceChecker::new(config);

    assert!(checker.check_skill_call("agent1", "summarize_pdf").is_ok());
    assert!(checker.check_skill_call("agent1", "detect_objects").is_ok());
}

#[test]
fn test_compliance_fl_task_blocking() {
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let config = ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    };
    let checker = ComplianceChecker::new(config);

    assert!(checker.check_fl_task("agent1", "biometric_task").is_err());
    assert!(checker.check_fl_task("agent1", "portrait_recognition").is_err());
}

#[test]
fn test_compliance_fl_task_allowed() {
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let config = ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    };
    let checker = ComplianceChecker::new(config);

    assert!(checker.check_fl_task("agent1", "grasping_v1").is_ok());
    assert!(checker.check_fl_task("agent1", "navigation_v2").is_ok());
}

#[test]
fn test_compliance_disabled() {
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let config = ComplianceConfig {
        enabled: false,
        country: "CN".to_string(),
    };
    let checker = ComplianceChecker::new(config);

    assert!(checker.check_skill_call("agent1", "face_detect").is_ok());
    assert!(checker.check_fl_task("agent1", "biometric_task").is_ok());
}

#[test]
fn test_delta_format_lora() {
    use clawfed::fl::FlClient;
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let compliance = ComplianceChecker::new(ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });
    let config = clawfed::fl::FlConfig { max_upload_mb: 10 };
    let client = FlClient::new("test_agent".to_string(), config, compliance);

    let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
    assert!(client.validate_delta_format(&lora_data).is_ok());
}

#[test]
fn test_delta_format_delta() {
    use clawfed::fl::FlClient;
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let compliance = ComplianceChecker::new(ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });
    let config = clawfed::fl::FlConfig { max_upload_mb: 10 };
    let client = FlClient::new("test_agent".to_string(), config, compliance);

    let delta_data = [0x44, 0x45, 0x4C, 0x54, 0x00, 0x01];
    assert!(client.validate_delta_format(&delta_data).is_ok());
}

#[test]
fn test_delta_format_empty() {
    use clawfed::fl::FlClient;
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let compliance = ComplianceChecker::new(ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });
    let config = clawfed::fl::FlConfig { max_upload_mb: 10 };
    let client = FlClient::new("test_agent".to_string(), config, compliance);

    assert!(client.validate_delta_format(&[]).is_err());
}

#[tokio::test]
async fn test_fl_upload_success() {
    use clawfed::fl::FlClient;
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let compliance = ComplianceChecker::new(ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });
    let config = clawfed::fl::FlConfig { max_upload_mb: 10 };
    let client = FlClient::new("test_agent".to_string(), config, compliance);

    let mut temp_file = NamedTempFile::new().unwrap();
    let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
    std::fs::write(&temp_file, &lora_data).unwrap();

    let result = client.upload_delta("grasping_v1", temp_file.path()).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_fl_upload_compliance_blocked() {
    use clawfed::fl::FlClient;
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let compliance = ComplianceChecker::new(ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });
    let config = clawfed::fl::FlConfig { max_upload_mb: 10 };
    let client = FlClient::new("test_agent".to_string(), config, compliance);

    let mut temp_file = NamedTempFile::new().unwrap();
    let lora_data = [0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01];
    std::fs::write(&temp_file, &lora_data).unwrap();

    let result = client.upload_delta("biometric_task", temp_file.path()).await;
    assert!(result.is_err());
    assert!(result.unwrap_err().to_string().contains("Compliance"));
}

#[tokio::test]
async fn test_fl_upload_size_exceeded() {
    use clawfed::fl::FlClient;
    use clawfed::net::{ComplianceChecker, ComplianceConfig};

    let compliance = ComplianceChecker::new(ComplianceConfig {
        enabled: true,
        country: "CN".to_string(),
    });
    let config = clawfed::fl::FlConfig { max_upload_mb: 10 };
    let client = FlClient::new("test_agent".to_string(), config, compliance);

    let mut temp_file = NamedTempFile::new().unwrap();
    let large_data = vec![0u8; 11 * 1024 * 1024];
    std::fs::write(&temp_file, &large_data).unwrap();

    let result = client.upload_delta("grasping_v1", temp_file.path()).await;
    assert!(result.is_err());
    assert!(result.unwrap_err().to_string().contains("exceeds maximum allowed"));
}

#[test]
fn test_config_parsing() {
    let config_str = r#"
agent_id = "my_agent"

[security]
trusted_agents = ["coordinator"]
use_sm_crypto = false

[compliance]
enabled = true
country = "CN"

[features]
enable_skills = true
enable_fl = false
fl_max_upload_mb = 10
"#;

    let config: toml::Value = config_str.parse().unwrap();
    assert_eq!(config["agent_id"].as_str(), Some("my_agent"));
    assert_eq!(config["compliance"]["country"].as_str(), Some("CN"));
    assert_eq!(config["features"]["fl_max_upload_mb"].as_integer(), Some(10));
}
