# Clawfed 多智能体部署指南

本文档详细说明如何部署和运行多个 OpenClaw 智能体，实现联邦学习和技能调用的互联互通。

## 📋 目录

- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [部署架构](#部署架构)
- [启动协调者](#启动协调者)
- [启动智能体](#启动智能体)
- [技能调用](#技能调用)
- [联邦学习](#联邦学习)
- [多智能体测试](#多智能体测试)
- [故障排查](#故障排查)

## 系统要求

- Rust 1.75+
- 网络端口可用（默认 50051-50054）
- 操作系统：Linux / macOS / Windows

## 快速开始

### 1. 构建项目

```bash
cargo build --release
```

### 2. 启动协调者

```bash
# 方式 1: 使用 cargo run
cargo run --bin clawfed -- server

# 方式 2: 使用编译后的二进制
./target/release/clawfed server

# 自定义地址
cargo run --bin clawfed -- server --addr "[::1]:50051" --agent-id coordinator
```

### 3. 启动智能体

```bash
# 终端 1: 启动视觉智能体
cargo run --bin clawfed -- agent --server --addr "[::1]:50052"

# 终端 2: 启动 NLP 智能体
cargo run --bin clawfed -- agent --server --addr "[::1]:50053"

# 终端 3: 启动机器人智能体
cargo run --bin clawfed -- agent --server --addr "[::1]:50054"
```

### 4. 测试技能调用

```bash
# 调用视觉智能体的技能
cargo run --bin clawfed -- call vision_agent_01 detect_objects --args '{"url": "https://example.com/image.jpg"}'

# 调用 NLP 智能体的技能
cargo run --bin clawfed -- call nlp_agent_01 summarize_pdf --args '{"file": "document.pdf"}'
```

## 部署架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Coordinator (50051)                     │
│  - Agent Registry                                         │
│  - Skill Discovery                                        │
│  - FL Coordinator Service                                  │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Vision Agent │    │  NLP Agent   │    │ Robot Agent  │
│   (50052)    │    │   (50053)    │    │   (50054)    │
│              │    │              │    │              │
│ Skills:      │    │ Skills:      │    │ Skills:      │
│ - detect_    │    │ - summarize_ │    │ - grasp_     │
│   objects    │    │   pdf        │    │   object    │
│ - analyze_   │    │ - process_   │    │ - navigate   │
│   image      │    │   text       │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
```

## 启动协调者

协调者是整个系统的核心，负责：
- 智能体注册和发现
- 技能路由
- 联邦学习协调

### 基本启动

```bash
clawfed server
```

### 自定义配置

```bash
clawfed server \
  --addr "[::1]:50051" \
  --agent-id coordinator
```

### 启动日志

```bash
clawfed server --log-level debug --log-format json
```

### 后台运行（Linux/macOS）

```bash
nohup clawfed server > coordinator.log 2>&1 &
echo $! > coordinator.pid
```

### 停止协调者

```bash
# 如果有 PID 文件
kill $(cat coordinator.pid)

# 或者直接查找进程
pkill -f "clawfed server"
```

## 启动智能体

智能体可以独立运行，也可以注册到协调者。

### 基本启动

```bash
clawfed agent --server
```

### 自定义配置

```bash
clawfed agent \
  --server \
  --addr "[::1]:50052" \
  --config ./clawfed.toml
```

### 不同类型的智能体

#### 1. 视觉智能体

```bash
clawfed agent --server --addr "[::1]:50052"
```

技能：
- `detect_objects` - 检测图像中的物体
- `analyze_image` - 分析图像内容

#### 2. NLP 智能体

```bash
clawfed agent --server --addr "[::1]:50053"
```

技能：
- `summarize_pdf` - 总结 PDF 文档
- `process_text` - 处理和分析文本

#### 3. 机器人智能体

```bash
clawfed agent --server --addr "[::1]:50054"
```

技能：
- `grasp_object` - 抓取物体
- `navigate` - 导航移动

### 批量启动脚本

创建 `start_agents.sh`:

```bash
#!/bin/bash

# Start Coordinator
echo "Starting Coordinator..."
clawfed server --addr "[::1]:50051" &
COORD_PID=$!
echo "Coordinator PID: $COORD_PID"

sleep 2

# Start Agents
echo "Starting Vision Agent..."
clawfed agent --server --addr "[::1]:50052" &
VISION_PID=$!

echo "Starting NLP Agent..."
clawfed agent --server --addr "[::1]:50053" &
NLP_PID=$!

echo "Starting Robot Agent..."
clawfed agent --server --addr "[::1]:50054" &
ROBOT_PID=$!

echo "All agents started!"
echo "PIDs: Coordinator=$COORD_PID, Vision=$VISION_PID, NLP=$NLP_PID, Robot=$ROBOT_PID"

# Save PIDs for cleanup
echo "$COORD_PID" > coordinator.pid
echo "$VISION_PID" > vision_agent.pid
echo "$NLP_PID" > nlp_agent.pid
echo "$ROBOT_PID" > robot_agent.pid
```

## 技能调用

智能体可以调用其他智能体的技能，实现协作。

### 基本语法

```bash
clawfed call <target_agent> <skill_name> --args <json_args> --addr <coordinator_addr>
```

### 示例

#### 1. 调用视觉技能

```bash
clawfed call vision_agent_01 detect_objects \
  --args '{"url": "https://example.com/image.jpg"}' \
  --addr "http://[::1]:50051"
```

响应：
```json
{
  "objects": [
    {"class": "person", "confidence": 0.95},
    {"class": "car", "confidence": 0.87}
  ],
  "count": 2
}
```

#### 2. 调用 NLP 技能

```bash
clawfed call nlp_agent_01 summarize_pdf \
  --args '{"file": "document.pdf"}' \
  --addr "http://[::1]:50051"
```

响应：
```json
{
  "summary": "Document summary generated",
  "key_points": ["Point 1", "Point 2"],
  "word_count": 150
}
```

#### 3. 调用机器人技能

```bash
clawfed call robot_agent_01 grasp_object \
  --args '{"object": "cup"}' \
  --addr "http://[::1]:50051"
```

### 合规拦截

在 CN 地区，某些技能会被自动拦截：

```bash
# 这会被拦截（CN-DATA-001）
clawfed call vision_agent_01 face_detect \
  --args '{"url": "test.jpg"}' \
  --addr "http://[::1]:50051"
```

错误响应：
```
Error: Status { code: PermissionDenied, message: "CN-DATA-001", ... }
```

## 联邦学习

智能体可以上传模型差分到协调者，参与联邦学习。

### 基本语法

```bash
clawfed fl upload-delta --task <task_id> --file <delta_file> --coordinator <coordinator_addr>
```

### 准备 Delta 文件

#### LoRA 格式

```bash
# 创建 LoRA 格式的 delta 文件
echo -ne '\x4C\x6F\x52\x41\x00\x01' > model.lora
```

#### DELTA 格式

```bash
# 创建 DELTA 格式的 delta 文件
echo -ne '\x44\x45\x4C\x54\x00\x01' > delta.delta
```

### 上传 Delta

#### 1. 上传抓取任务模型

```bash
clawfed fl upload-delta \
  --task grasping_v1 \
  --file model.lora \
  --coordinator "http://[::1]:50051"
```

响应：
```
✓ Delta uploaded successfully to task: grasping_v1
Delta ID: grasping_v1-<uuid>
```

#### 2. 上传导航任务模型

```bash
clawfed fl upload-delta \
  --task navigation_v2 \
  --file delta.delta \
  --coordinator "http://[::1]:50051"
```

### 合规拦截

在 CN 地区，某些 FL 任务会被自动拦截：

```bash
# 这会被拦截（CN-DATA-001）
clawfed fl upload-delta \
  --task biometric_task \
  --file model.lora \
  --coordinator "http://[::1]:50051"
```

错误响应：
```
Error: Compliance check failed: CN-DATA-001
```

### 文件大小限制

默认最大上传大小：10MB

```bash
# 文件超过 10MB 会被拒绝
clawfed fl upload-delta \
  --task grasping_v1 \
  --file large_model.lora \
  --coordinator "http://[::1]:50051"
```

错误响应：
```
Error: File size 15 MB exceeds maximum allowed 10 MB
```

## 多智能体测试

我们提供了自动化测试脚本，可以快速验证多智能体协作。

### Linux/macOS

```bash
chmod +x scripts/multi_agent_test.sh
./scripts/multi_agent_test.sh
```

### Windows (PowerShell)

```powershell
.\scripts\multi_agent_test.ps1
```

### 测试内容

脚本会自动执行以下测试：

1. **启动协调者和多个智能体**
   - Coordinator (50051)
   - Vision Agent (50052)
   - NLP Agent (50053)
   - Robot Agent (50054)

2. **测试技能调用**
   - Vision Agent: `detect_objects`
   - NLP Agent: `summarize_pdf`
   - Robot Agent: `grasp_object`

3. **测试联邦学习**
   - 上传 `grasping_v1` 任务 delta
   - 上传 `navigation_v2` 任务 delta

4. **测试合规拦截**
   - 阻止 `face_detect` 技能调用
   - 阻止 `biometric_task` FL 上传

### 预期输出

```
=== Clawfed Multi-Agent Test ===
Starting Coordinator...
Coordinator PID: 12345
Starting Agent vision_agent_01 on port 50052...
Agent vision_agent_01 PID: 12346
Starting Agent nlp_agent_01 on port 50053...
Agent nlp_agent_01 PID: 12347
Starting Agent robot_agent_01 on port 50054...
Agent robot_agent_01 PID: 12348
All agents started!

=== Testing Skill Calls ===
Testing: vision_agent_01 -> detect_objects
✓ Called skill 'detect_objects' on agent 'vision_agent_01'
  Result: {"objects":[{"class":"person","confidence":0.95}],"count":1}

Testing: nlp_agent_01 -> summarize_pdf
✓ Called skill 'summarize_pdf' on agent 'nlp_agent_01'
  Result: {"summary":"Document summary generated","key_points":["Point 1"],"word_count":150}

Testing: robot_agent_01 -> grasp_object
✓ Called skill 'grasp_object' on agent 'robot_agent_01'
  Result: {"status":"success","object":"cup"}

=== Testing Federated Learning ===
Testing FL Upload: grasping_v1
✓ Delta uploaded successfully to task: grasping_v1

Testing FL Upload: navigation_v2
✓ Delta uploaded successfully to task: navigation_v2

=== Testing Compliance Blocking ===
Testing blocked skill call...
Expected: Compliance blocked

Testing blocked FL task...
Expected: Compliance blocked

=== All tests completed successfully! ===
```

## 故障排查

### 端口被占用

**问题**：
```
Error: Os { code: 10048, kind: AddrInUse, message: "Address already in use" }
```

**解决方案**：
```bash
# 查找占用端口的进程
netstat -ano | findstr :50051

# 杀死进程（Windows）
taskkill /PID <PID> /F

# 或者使用不同的端口
clawfed server --addr "[::1]:50060"
```

### 连接被拒绝

**问题**：
```
Error: Connection refused
```

**解决方案**：
1. 确保协调者正在运行
2. 检查防火墙设置
3. 验证地址格式（使用 `[::1]` 而不是 `localhost`）

### 合规拦截

**问题**：
```
Error: Compliance check failed: CN-DATA-001
```

**解决方案**：
1. 检查技能名称或任务 ID 是否包含敏感词
2. 修改配置文件中的 `country` 设置
3. 使用合规的技能名称和任务 ID

### 文件未找到

**问题**：
```
Error: File not found: delta.lora
```

**解决方案**：
```bash
# 检查文件是否存在
ls -la delta.lora

# 使用绝对路径
clawfed fl upload-delta --task grasping_v1 --file /path/to/delta.lora
```

### 编译错误

**问题**：
```
error: failed to compile
```

**解决方案**：
```bash
# 清理并重新构建
cargo clean
cargo build --release

# 更新依赖
cargo update
```

## 生产环境部署

### 使用 systemd (Linux)

创建 `/etc/systemd/system/clawfed-coordinator.service`:

```ini
[Unit]
Description=Clawfed Coordinator
After=network.target

[Service]
Type=simple
User=clawfed
WorkingDirectory=/opt/clawfed
ExecStart=/opt/clawfed/clawfed server --addr "[::1]:50051"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl enable clawfed-coordinator
sudo systemctl start clawfed-coordinator
sudo systemctl status clawfed-coordinator
```

### 使用 Docker

创建 `Dockerfile`:

```dockerfile
FROM rust:1.75 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates
COPY --from=builder /app/target/release/clawfed /usr/local/bin/
EXPOSE 50051
CMD ["clawfed", "server"]
```

构建和运行：
```bash
docker build -t clawfed .
docker run -p 50051:50051 clawfed
```

### 使用 Docker Compose

创建 `docker-compose.yml`:

```yaml
version: '3.8'
services:
  coordinator:
    image: clawfed
    command: server --addr "[::1]:50051"
    ports:
      - "50051:50051"

  vision-agent:
    image: clawfed
    command: agent --server --addr "[::1]:50052"
    depends_on:
      - coordinator

  nlp-agent:
    image: clawfed
    command: agent --server --addr "[::1]:50053"
    depends_on:
      - coordinator

  robot-agent:
    image: clawfed
    command: agent --server --addr "[::1]:50054"
    depends_on:
      - coordinator
```

启动：
```bash
docker-compose up -d
```

## 监控和日志

### 查看日志

```bash
# JSON 格式日志
clawfed server --log-format json | jq '.'

# Pretty 格式日志
clawfed server --log-format pretty

# 过滤特定事件
clawfed server --log-format json | jq 'select(.event == "skill_call")'
```

### 结构化日志字段

所有日志包含以下字段：
- `agent_id`: 智能体 ID
- `peer`: 对端智能体 ID
- `event`: 事件类型
- `status`: 状态（started, success, error, blocked）
- `timestamp`: 时间戳

### 关键事件

- `server_start`: 服务器启动
- `agent_register`: 智能体注册
- `skill_call`: 技能调用
- `compliance_blocked`: 合规拦截
- `fl_upload`: FL 上传

## 性能优化

### 调整并发

```bash
# 设置 Tokio 运行时线程数
export TOKIO_WORKER_THREADS=4
clawfed server
```

### 启用 TLS

```bash
cargo build --features tls
clawfed server --tls-cert server.crt --tls-key server.key
```

### 调整日志级别

生产环境使用 `info` 或 `warn`：
```bash
clawfed server --log-level warn
```

## 安全建议

1. **使用 TLS**: 在生产环境中启用 TLS 加密
2. **网络隔离**: 将协调者和智能体部署在内网
3. **访问控制**: 配置防火墙规则
4. **定期更新**: 保持依赖项最新
5. **审计日志**: 启用详细的日志记录

## 下一步

- 查看 [USAGE.md](USAGE.md) 了解更多 CLI 用法
- 查看 [README.md](README.md) 了解项目概述
- 查看 [clawfed.toml](clawfed.toml) 了解配置选项
