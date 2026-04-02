mod fl;

use anyhow::Result;
use clap::{Parser, Subcommand};
use tracing::{error, info};
use tracing_subscriber::{fmt, EnvFilter};

#[derive(Parser, Debug)]
#[command(name = "clawfed")]
#[command(about = "OpenClaw Federal Collaboration Framework", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    #[arg(long, global = true, help = "Log level (trace, debug, info, warn, error)")]
    pub log_level: Option<String>,

    #[arg(long, global = true, help = "Log format (json, pretty)")]
    pub log_format: Option<String>,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    #[command(name = "server")]
    Server {
        #[arg(long, default_value = "[::1]:50051", help = "Server bind address")]
        addr: String,

        #[arg(long, default_value = "coordinator", help = "Agent ID for this server")]
        agent_id: String,
    },

    #[command(name = "agent")]
    Agent {
        #[arg(long, help = "Path to configuration file")]
        config: Option<String>,

        #[arg(long, help = "Start agent in server mode")]
        server: bool,

        #[arg(long, default_value = "[::1]:50052", help = "Server bind address")]
        addr: String,
    },

    #[command(name = "call")]
    Call {
        #[arg(help = "Target agent ID")]
        target: String,

        #[arg(help = "Skill name to call")]
        skill: String,

        #[arg(long, help = "JSON arguments for the skill")]
        args: Option<String>,

        #[arg(long, default_value = "http://[::1]:50051", help = "Target agent address")]
        addr: String,
    },

    #[command(name = "fl")]
    Fl {
        #[command(subcommand)]
        commands: fl::FlCommands,
    },
}

impl Cli {
    pub fn init_logging(&self) {
        let log_level = self.log_level.as_deref().unwrap_or("info");
        let log_format = self.log_format.as_deref().unwrap_or("json");

        let env_filter = EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new(log_level));

        let subscriber = if log_format == "json" {
            fmt().json().with_env_filter(env_filter).finish()
        } else {
            fmt().pretty().with_env_filter(env_filter).finish()
        };

        tracing::subscriber::set_global_default(subscriber)
            .expect("Failed to set tracing subscriber");
    }

    pub async fn run(self) -> Result<()> {
        self.init_logging();

        info!(
            event = "clawfed_start",
            status = "started",
            "Clawfed CLI starting"
        );

        match self.command {
            Commands::Server { addr, agent_id } => {
                self.handle_server(addr, agent_id).await
            }
            Commands::Agent { config, server, addr } => {
                self.handle_agent(config, server, addr).await
            }
            Commands::Call { target, skill, args, addr } => {
                self.handle_call(target, skill, args, addr).await
            }
            Commands::Fl { commands } => {
                let agent_id = "default_agent".to_string();
                fl::handle_fl_commands(agent_id, commands).await
            }
        }
    }

    async fn handle_server(&self, addr: String, agent_id: String) -> Result<()> {
        use crate::net::{AgentRegistry, ComplianceChecker, start_server};
        use std::sync::Arc;

        info!(
            address = %addr,
            agent_id = %agent_id,
            event = "server_start",
            status = "starting",
            "Starting coordinator server"
        );

        let registry = Arc::new(AgentRegistry::new());
        let compliance = Arc::new(ComplianceChecker::new(crate::net::ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        }));

        println!("✓ Coordinator server starting on {}", addr);
        println!("  Agent ID: {}", agent_id);
        println!("  Press Ctrl+C to stop");

        start_server(addr, registry, compliance).await?;

        Ok(())
    }

    async fn handle_agent(&self, config: Option<String>, server: bool, addr: String) -> Result<()> {
        use crate::agent::{Agent, AgentManager};
        use crate::net::{AgentRegistry, ComplianceChecker, start_server};
        use crate::skill::{create_default_skills, SkillRegistry};
        use std::sync::Arc;

        let config_path = config.unwrap_or_else(|| "./clawfed.toml".to_string());

        info!(
            config = %config_path,
            server_mode = %server,
            address = %addr,
            event = "agent_start",
            status = "starting",
            "Starting agent with configuration"
        );

        if !std::path::Path::new(&config_path).exists() {
            error!(
                config = %config_path,
                event = "agent_start_failed",
                status = "error",
                reason = "CONFIG-NOT-FOUND",
                "Configuration file not found"
            );
            return Err(anyhow::anyhow!("Configuration file not found: {}", config_path));
        }

        let agent_id = "agent_01".to_string();
        let agent = Agent::new(agent_id.clone(), "127.0.0.1".to_string(), 50052)
            .with_skills(vec!["detect_objects".to_string(), "summarize_pdf".to_string()]);

        let registry = Arc::new(AgentRegistry::new());
        let compliance = ComplianceChecker::new(crate::net::ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        });

        let agent_manager = AgentManager::new(agent, registry.clone(), compliance);

        if server {
            println!("✓ Agent starting in server mode on {}", addr);
            println!("  Agent ID: {}", agent_id);
            println!("  Press Ctrl+C to stop");

            start_server(addr, registry, Arc::new(ComplianceChecker::new(crate::net::ComplianceConfig {
                enabled: true,
                country: "CN".to_string(),
            })).await?;
        } else {
            println!("✓ Agent started with config: {}", config_path);
            println!("  Agent ID: {}", agent_id);
            println!("  Press Ctrl+C to stop");

            tokio::signal::ctrl_c().await?;
            info!(event = "agent_stop", status = "stopped", "Agent stopped by user");
        }

        Ok(())
    }

    async fn handle_call(&self, target: String, skill: String, args: Option<String>, addr: String) -> Result<()> {
        use crate::net::AgentClient;

        info!(
            agent_id = "default_agent",
            target = %target,
            skill = %skill,
            args = %args.as_deref().unwrap_or("{}"),
            event = "skill_call",
            status = "started",
            "Calling remote skill"
        );

        let compliance = crate::net::ComplianceChecker::new(crate::net::ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        });

        if let Err(e) = compliance.check_skill_call("default_agent", &skill) {
            error!(
                agent_id = "default_agent",
                skill = %skill,
                error = %e,
                event = "skill_call_failed",
                status = "blocked",
                "Skill call blocked by compliance"
            );
            return Err(anyhow::anyhow!("Compliance check failed: {}", e.message()));
        }

        let mut client = AgentClient::connect(addr).await?;
        let args_json = args.unwrap_or_else(|| "{}".to_string());
        let response = client.call_skill(&target, &skill, &args_json).await?;

        if response.success {
            println!("✓ Called skill '{}' on agent '{}'", skill, target);
            println!("  Result: {}", response.result_json);
        } else {
            println!("✗ Skill call failed: {}", response.error_message);
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cli_parsing() {
        let cli = Cli::try_parse_from(["clawfed", "server"]);
        assert!(cli.is_ok());

        let cli = Cli::try_parse_from(["clawfed", "agent", "--config", "./test.toml"]);
        assert!(cli.is_ok());

        let cli = Cli::try_parse_from([
            "clawfed",
            "call",
            "vision_agent_01",
            "detect_objects",
            "--args",
            r#"{"url": "https://example.com/image.jpg"}"#,
        ]);
        assert!(cli.is_ok());

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
    fn test_cli_invalid_command() {
        let cli = Cli::try_parse_from(["clawfed", "invalid"]);
        assert!(cli.is_err());
    }
}
