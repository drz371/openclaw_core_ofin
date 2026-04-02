# Clawfed - OpenClaw Federal Collaboration Framework

A lightweight, secure, and compliant federal collaboration framework for OpenClaw agents.

## Features

- **Multi-Agent Collaboration**: Connect multiple OpenClaw agents for federated operations
- **Federal Skill Calls**: Call skills on remote agents with JSON-in/JSON-out support
- **Federated Learning**: Upload model deltas or LoRA weights (no raw data)
- **Agent Discovery**: Automatic agent registration and skill discovery
- **Compliance Enforcement**: Automatic blocking of sensitive operations in regulated regions
- **Secure Communication**: gRPC-based communication with TLS and SM-Crypto support
- **Zero Overhead**: Feature-gated compilation for unused functionality

## Installation

```bash
cargo build --release
```

## Configuration

Create a `clawfed.toml` file:

```toml
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
```

## Usage

### Start Coordinator

```bash
# Start coordinator server
clawfed server

# Custom address and agent ID
clawfed server --addr "[::1]:50051" --agent-id coordinator
```

### Start Agent

```bash
# Start agent in server mode
clawfed agent --server --addr "[::1]:50052"

# Start agent with config
clawfed agent --config ./clawfed.toml
```

### Multi-Agent Setup

```bash
# Terminal 1: Start coordinator
clawfed server --addr "[::1]:50051"

# Terminal 2: Start vision agent
clawfed agent --server --addr "[::1]:50052"

# Terminal 3: Start NLP agent
clawfed agent --server --addr "[::1]:50053"

# Terminal 4: Call remote skill
clawfed call vision_agent_01 detect_objects --args '{"url": "https://example.com/image.jpg"}'
```

### Call Remote Skill

```bash
clawfed call vision_agent_01 detect_objects --args '{"url": "https://example.com/image.jpg"}' --addr "http://[::1]:50051"
```

### Federated Learning

Upload model delta to coordinator:

```bash
clawfed fl upload-delta --task grasping_v1 --file delta.lora --coordinator "http://[::1]:50051"
```

### Debug Mode

```bash
clawfed server --log-level debug --log-format json
```

## Compliance Rules

When `compliance.country = "CN"`, the following operations are automatically blocked:

**Skill Calls**:
- Skills containing: `face`, `raw`, `id_card`, `generate`
- Example: `face_detect`, `raw_data`, `id_card_generate`

**Federated Learning Tasks**:
- Task IDs containing: `biometric`, `portrait`
- Example: `biometric_task`, `portrait_recognition`

Blocked operations return error: `tonic::Status::permission_denied("CN-DATA-001")`

## Security Features

- **TLS**: Secure communication with `rustls`
- **SM-Crypto**: Chinese national cryptography support
- **Certificate Parsing**: X.509 certificate validation
- **Data Validation**: Only model deltas or LoRA weights allowed (no raw data)

## Development

### Run Tests

```bash
cargo test
```

### Linting

```bash
cargo clippy -- -D warnings
```

### Build with Features

```bash
cargo build --features "tls,sm-crypto,auth"
```

## Project Structure

```
src/
├── agent/      # Agent lifecycle management
├── skill/      # Skill registration and remote calls
├── fl/         # Federated learning (#[cfg(feature = "fl")])
├── net/        # Secure communication (auth/encryption/compliance)
├── proto/      # gRPC protocol definitions
└── cli/        # CLI command implementation

scripts/
├── multi_agent_test.sh    # Linux/macOS test script
└── multi_agent_test.ps1   # Windows test script
```

## Documentation

- [TECHNICAL.md](TECHNICAL.md) - Technical stack, operations, and maintenance guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Multi-agent deployment guide
- [USAGE.md](USAGE.md) - Detailed CLI usage examples
- [VERIFICATION.md](VERIFICATION.md) - Project verification report
- [FUNCTIONAL_TEST.md](FUNCTIONAL_TEST.md) - Functional testing guide
- [FUNCTIONAL_TEST_REPORT.md](FUNCTIONAL_TEST_REPORT.md) - Functional test report
- [SANDBOX_TEST.md](SANDBOX_TEST.md) - Sandbox and VM testing guide
- [FINAL_VERIFICATION_REPORT.md](FINAL_VERIFICATION_REPORT.md) - Final verification and debugging report

## Quick Start with Multi-Agent Test

Run the automated multi-agent test:

**Linux/macOS:**
```bash
chmod +x scripts/multi_agent_test.sh
./scripts/multi_agent_test.sh
```

**Windows (PowerShell):**
```powershell
.\scripts\multi_agent_test.ps1
```

This will automatically:
1. Start a coordinator server
2. Launch multiple agents (vision, NLP, robot)
3. Test skill calls between agents
4. Test federated learning uploads
5. Verify compliance blocking

## Memory Requirements

Target: ≤ 50MB (tested on Jetson Orin)

## Dependencies

Total crates: < 30 (excluding dev-dependencies)

## License

OpenClaw Internal Use Only
