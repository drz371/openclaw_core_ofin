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

        #[arg(long, default_value = "agent_01", help = "Agent ID (agent_01=OpenClaw, agent_02=Hermes)")]
        agent_id: String,
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

    #[command(name = "orchestrate")]
    Orchestrate {
        #[arg(help = "The goal to achieve (e.g., '分析全球AI发展趋势并生成报告')")]
        goal: String,

        #[arg(long, default_value = "[::1]:50051", help = "Coordinator address")]
        coordinator: String,
    },
}

impl Cli {
    pub fn init_logging(&self) {
        let log_level = self.log_level.as_deref().unwrap_or("info");
        let log_format = self.log_format.as_deref().unwrap_or("json");

        let env_filter = EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new(log_level));

        if log_format == "json" {
            let subscriber = fmt().json().with_env_filter(env_filter).finish();
            tracing::subscriber::set_global_default(subscriber)
                .expect("Failed to set tracing subscriber");
        } else {
            let subscriber = fmt().pretty().with_env_filter(env_filter).finish();
            tracing::subscriber::set_global_default(subscriber)
                .expect("Failed to set tracing subscriber");
        }
    }

    pub async fn run(self) -> Result<()> {
        self.init_logging();

        info!(
            event = "clawfed_start",
            status = "started",
            "Clawfed CLI starting"
        );

        match self.command {
            Commands::Server { ref addr, ref agent_id } => {
                self.handle_server(addr, agent_id).await
            }
            Commands::Agent { ref config, server, ref addr, ref agent_id } => {
                self.handle_agent(config.clone(), server, addr.clone(), agent_id.clone()).await
            }
            Commands::Call { ref target, ref skill, ref args, ref addr } => {
                self.handle_call(target.clone(), skill.clone(), args.clone(), addr.clone()).await
            }
            Commands::Fl { commands } => {
                let agent_id = "default_agent".to_string();
                fl::handle_fl_commands(agent_id, commands).await
            }
            Commands::Orchestrate { ref goal, ref coordinator } => {
                self.handle_orchestrate(goal, coordinator).await
            }
        }
    }

    async fn handle_server(&self, addr: &str, agent_id: &str) -> Result<()> {
        use crate::net::{AgentRegistry, ComplianceChecker, start_server};
        use std::sync::Arc;

        info!(
            address = %addr,
            agent_id = %agent_id,
            event = "server_start",
            status = "starting",
            "Starting coordinator server"
        );
        let compliance = Arc::new(ComplianceChecker::new(crate::net::ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        }));

        println!("✓ Coordinator server starting on {}", addr);
        println!("  Agent ID: {}", agent_id);
        println!("  Press Ctrl+C to stop");

        let registry = Arc::new(AgentRegistry::new());
        start_server(addr.to_string(), registry, compliance).await
            .map_err(|e| anyhow::anyhow!("Server error: {}", e))?;

        Ok(())
    }

    async fn handle_agent(&self, config: Option<String>, server: bool, addr: String, agent_id: String) -> Result<()> {
        use crate::agent::{Agent, AgentManager};
        use crate::net::{AgentRegistry, ComplianceChecker, start_server};
        use std::sync::Arc;

        let config_path = config.unwrap_or_else(|| "./clawfed.toml".to_string());

        info!(
            config = %config_path,
            server_mode = %server,
            address = %addr,
            agent_id = %agent_id,
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

        let port: u16 = if addr.starts_with('[') {
            addr.split(']').nth(1)
                .and_then(|p| p.trim_start_matches(':').parse().ok())
                .unwrap_or(50052)
        } else {
            addr.split(':').last()
                .and_then(|p| p.parse().ok())
                .unwrap_or(50052)
        };

        let host = if addr.starts_with('[') {
            addr.split('[').nth(1)
                .and_then(|p| p.split(']').next())
                .unwrap_or("::1")
        } else {
            addr.split(':').next().unwrap_or("127.0.0.1")
        };

        let skills = match agent_id.as_str() {
            "agent_02" => vec![
                "analyze_context".to_string(),
                "generate_response".to_string(),
                "translate_text".to_string(),
            ],
            _ => vec![
                "detect_objects".to_string(),
                "summarize_pdf".to_string(),
                "process_data".to_string(),
            ],
        };

        let registry = Arc::new(AgentRegistry::new());
        let compliance = ComplianceChecker::new(crate::net::ComplianceConfig {
            enabled: true,
            country: "CN".to_string(),
        });

        if server {
            let agent_skills = skills.clone();
            let agent_address = host.to_string();
            let mut local_agent = Agent::new(agent_id.clone(), agent_address.clone(), port)
                .with_skills(agent_skills);

            registry.register(local_agent.to_agent_info()).await
                .map_err(|e| anyhow::anyhow!("Failed to register agent: {}", e))?;

            let agent_manager = crate::agent::AgentManager::new(local_agent, AgentRegistry::new(), compliance);

            match agent_manager.register_with_coordinator(&std::env::var("COORDINATOR_ADDR").unwrap_or_else(|_| "http://[::1]:50051".to_string())).await {
                Ok(_) => println!("  → Registered with coordinator"),
                Err(e) => println!("  ⚠ Failed to register with coordinator: {}", e),
            }

            println!("✓ Agent starting in server mode on {}", addr);
            println!("  Agent ID: {}", agent_id);
            println!("  Press Ctrl+C to stop");

            start_server(addr, registry, Arc::new(ComplianceChecker::new(crate::net::ComplianceConfig {
                enabled: true,
                country: "CN".to_string(),
            }))).await
                .map_err(|e| anyhow::anyhow!("Server error: {}", e))?;
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

        let target_addr = {
            let mut discover_client = AgentClient::connect(addr.clone()).await
                .map_err(|e| anyhow::anyhow!("Failed to connect to coordinator: {}", e))?;

            let response = discover_client.get_agent(&target).await
                .map_err(|e| anyhow::anyhow!("Failed to get agent: {}", e))?;

            let agent = response.agent
                .ok_or_else(|| anyhow::anyhow!("Agent {} info not found", target))?;

            let discovered_addr = if agent.address.contains(':') {
                format!("http://[{}]:{}", agent.address, agent.port)
            } else {
                format!("http://{}:{}", agent.address, agent.port)
            };
            info!(target = %target, discovered_addr = %discovered_addr, "Discovered target agent address");
            discovered_addr
        };

        let mut client = AgentClient::connect(target_addr).await
            .map_err(|e| anyhow::anyhow!("Failed to connect: {}", e))?;
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

    async fn handle_orchestrate(&self, goal: &str, coordinator: &str) -> Result<()> {
        use crate::orchestrator::{AutonomousOrchestrator, GoalPlanner, TaskStatus};

        info!(
            goal = %goal,
            coordinator = %coordinator,
            event = "orchestration_start",
            "Starting autonomous orchestration"
        );

        println!("╔══════════════════════════════════════════════════════════════╗");
        println!("║           🎯 自主任务编排器启动 🎯                         ║");
        println!("╚══════════════════════════════════════════════════════════════╝");
        println!();
        println!("目标: {}", goal);
        println!("协调器: {}", coordinator);
        println!();

        let orchestrator = AutonomousOrchestrator::new(coordinator);

        println!("→ 正在进行目标分解...");
        let plan = GoalPlanner::decompose(goal);
        println!("  ✓ 已分解为 {} 个子任务:", plan.sub_tasks.len());

        for (i, task) in plan.sub_tasks.iter().enumerate() {
            println!("    [{}/{}] {} -> Agent:{:?}, Skill:{:?}",
                i + 1,
                plan.sub_tasks.len(),
                task.description,
                task.target_agent,
                task.skill
            );
        }
        println!();

        println!("→ 正在执行自主任务流...");
        let result = orchestrator.execute(goal).await;

        println!();
        println!("╔══════════════════════════════════════════════════════════════╗");
        println!("║                    执行结果汇总                            ║");
        println!("╚══════════════════════════════════════════════════════════════╝");
        println!();

        if result.success {
            println!("✓ 任务编排执行成功!");
        } else {
            println!("✗ 任务编排执行完成，但存在失败");
        }

        println!();
        println!("📊 执行统计:");
        println!("   - 总任务数: {}", result.total_tasks);
        println!("   - 已完成: {} ✓", result.completed_tasks);
        println!("   - 失败: {} ✗", result.failed_tasks);
        println!();

        println!("📋 子任务详情:");
        for task in &result.plan.sub_tasks {
            let status = match task.status {
                TaskStatus::Completed => "✓ 完成",
                TaskStatus::Failed => "✗ 失败",
                TaskStatus::InProgress => "⚙ 进行中",
                TaskStatus::Pending => "○ 等待",
                TaskStatus::Retrying => "↻ 重试",
            };
            let result_preview = task.result.as_ref()
                .map(|r: &String| format!(" ({}...)", &r.chars().take(50).collect::<String>()))
                .unwrap_or_default();

            println!("   {} {} {}", status, task.id, result_preview);
        }

        if result.federated_delta.is_some() {
            println!();
            println!("🔄 联邦学习 Delta 已生成，共 {} 字节",
                result.federated_delta.as_ref().unwrap().len());
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

        let cli = Cli::try_parse_from(["clawfed", "agent", "--config", "./test.toml", "--server"]);
        assert!(cli.is_ok());

        let cli = Cli::try_parse_from([
            "clawfed",
            "agent",
            "--agent-id",
            "agent_02",
            "--server",
            "--addr",
            "0.0.0.0:50053",
        ]);
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
