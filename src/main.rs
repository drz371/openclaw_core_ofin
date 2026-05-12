mod agent;
mod cli;
mod fl;
mod llm_integration;
mod net;
mod orchestrator;
mod proto;
mod skill;

use clap::Parser;
use cli::Cli;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    cli.run().await
}
