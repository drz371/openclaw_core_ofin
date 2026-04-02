# Clawfed 技术文档

本文档详细说明 Clawfed 项目的技术栈、操作指令和运行维护指南。

## 📚 目录

- [技术栈](#技术栈)
- [操作指令](#操作指令)
- [运行维护](#运行维护)
- [故障排查](#故障排查)
- [生产环境部署](#生产环境部署)

---

## 技术栈

### 核心技术

#### 语言和运行时
- **Rust**: 1.75+
  - 内存安全保证
  - 零成本抽象
  - 优秀的并发支持

- **Tokio**: 1.35
  - 异步运行时
  - 高性能 I/O
  - 跨平台支持

#### 通信协议
- **gRPC**: 基于 HTTP/2 的高性能 RPC 框架
  - **tonic**: 0.11 - Rust gRPC 库
  - **prost**: 0.12 - Protocol Buffers 编译器

#### 序列化和配置
- **serde**: 1.0 - 序列化/反序列化框架
- **serde_json**: 1.0 - JSON 支持
- **toml**: 0.8 - TOML 配置文件解析

#### 日志和追踪
- **tracing**: 0.1 - 结构化日志和追踪
- **tracing-subscriber**: 0.3 - 日志订阅器
  - JSON 格式输出
  - 环境过滤器
  - 性能分析支持

#### 命令行界面
- **clap**: 4.4 - 命令行参数解析
  - 派生宏支持
  - 自动帮助生成
  - 子命令管理

### 安全特性

#### 加密和认证
- **rustls**: 0.21 (feature: `tls`)
  - 纯 Rust TLS 实现
  - 无 OpenSSL 依赖
  - 高性能加密

- **sm-crypto**: 0.4 (feature: `sm-crypto`)
  - 中国国密算法支持
  - SM2/SM3/SM4
  - 符合国密标准

- **x509-parser**: 0.16 (feature: `auth`)
  - X.509 证书解析
  - 证书链验证
  - 公钥提取

### 其他依赖

#### 错误处理
- **anyhow**: 1.0 - 简化错误处理
- **thiserror**: 1.0 - 派生错误类型

#### 工具库
- **uuid**: 1.6 - UUID 生成
  - v4 随机 UUID
  - serde 序列化支持

#### 测试
- **tempfile**: 3.8 - 临时文件管理

### 编译依赖

- **tonic-build**: 0.11
  - 从 .proto 文件生成 Rust 代码
  - 服务端和客户端代码生成

### 项目结构

```
clawfed/
├── Cargo.toml                 # 项目配置和依赖
├── build.rs                   # 构建脚本（proto 代码生成）
├── clawfed.toml              # 运行时配置
├── proto/
│   └── clawfed.proto         # gRPC 协议定义
├── src/
│   ├── main.rs               # 二进制入口
│   ├── lib.rs               # 库入口
│   ├── agent/               # 智能体管理
│   │   └── mod.rs
│   ├── skill/               # 技能系统
│   │   └── mod.rs
│   ├── fl/                  # 联邦学习
│   │   └── mod.rs
│   ├── net/                 # 网络通信
│   │   ├── mod.rs
│   │   ├── compliance.rs     # 合规检查
│   │   ├── server.rs        # gRPC 服务端
│   │   └── client.rs        # gRPC 客户端
│   ├── proto/               # 生成的 proto 代码
│   │   └── mod.rs
│   └── cli/                 # CLI 命令
│       ├── mod.rs
│       └── fl.rs
├── scripts/
│   ├── multi_agent_test.sh   # Linux/macOS 测试脚本
│   └── multi_agent_test.ps1  # Windows 测试脚本
└── tests/
    └── integration_test.rs   # 集成测试
```

### 特性标志

```toml
[features]
default = ["tls"]
tls = ["dep:rustls"]
sm-crypto = ["dep:sm-crypto"]
auth = ["dep:x509-parser"]
fl = []
```

---

## 操作指令

### 基本命令

#### 1. 启动协调者

协调者是整个系统的核心，负责智能体注册、技能发现和 FL 协调。

```bash
# 基本启动
clawfed server

# 自定义地址和 ID
clawfed server --addr "[::1]:50051" --agent-id coordinator

# 调试模式
clawfed server --log-level debug --log-format json

# 使用配置文件
clawfed server --config ./coordinator.toml
```

**参数说明**：
- `--addr`: 服务器绑定地址（默认：`[::1]:50051`）
- `--agent-id`: 智能体 ID（默认：`coordinator`）
- `--log-level`: 日志级别（trace/debug/info/warn/error）
- `--log-format`: 日志格式（json/pretty）
- `--config`: 配置文件路径

#### 2. 启动智能体

智能体可以独立运行，也可以注册到协调者。

```bash
# 服务器模式
clawfed agent --server

# 自定义地址
clawfed agent --server --addr "[::1]:50052"

# 使用配置文件
clawfed agent --config ./agent.toml

# 仅客户端模式
clawfed agent --config ./agent.toml
```

**参数说明**：
- `--server`: 启动为服务器模式
- `--addr`: 服务器绑定地址（默认：`[::1]:50052`）
- `--config`: 配置文件路径

#### 3. 技能调用

调用其他智能体的技能，实现协作。

```bash
# 基本语法
clawfed call <target_agent> <skill_name> --args <json_args> --addr <coordinator_addr>

# 示例 1: 调用视觉技能
clawfed call vision_agent_01 detect_objects \
  --args '{"url": "https://example.com/image.jpg"}' \
  --addr "http://[::1]:50051"

# 示例 2: 调用 NLP 技能
clawfed call nlp_agent_01 summarize_pdf \
  --args '{"file": "document.pdf"}' \
  --addr "http://[::1]:50051"

# 示例 3: 调用机器人技能
clawfed call robot_agent_01 grasp_object \
  --args '{"object": "cup"}' \
  --addr "http://[::1]:50051"
```

**参数说明**：
- `target_agent`: 目标智能体 ID
- `skill_name`: 技能名称
- `--args`: JSON 格式的参数
- `--addr`: 协调者地址（默认：`http://[::1]:50051`）

#### 4. 联邦学习

上传模型差分到协调者，参与联邦学习。

```bash
# 基本语法
clawfed fl upload-delta --task <task_id> --file <delta_file> --coordinator <coordinator_addr>

# 示例 1: 上传 LoRA 格式
clawfed fl upload-delta \
  --task grasping_v1 \
  --file model.lora \
  --coordinator "http://[::1]:50051"

# 示例 2: 上传 DELTA 格式
clawfed fl upload-delta \
  --task navigation_v2 \
  --file delta.delta \
  --coordinator "http://[::1]:50051"
```

**参数说明**：
- `--task`: 任务 ID
- `--file`: Delta 文件路径
- `--coordinator`: 协调者地址（默认：`http://[::1]:50051`）

### 开发命令

#### 构建和测试

```bash
# 开发构建
cargo build

# 发布构建
cargo build --release

# 运行测试
cargo test

# 运行特定测试
cargo test test_agent_registry

# 测试并显示输出
cargo test -- --nocapture

# 代码检查
cargo clippy -- -D warnings

# 格式化代码
cargo fmt

# 检查格式
cargo fmt --check
```

#### 依赖管理

```bash
# 更新依赖
cargo update

# 检查过时依赖
cargo outdated

# 清理构建缓存
cargo clean

# 清理并重新构建
cargo clean && cargo build --release
```

#### 文档生成

```bash
# 生成文档
cargo doc

# 生成并打开文档
cargo doc --open

# 生成私有文档
cargo doc --document-private-items
```

### 多智能体测试

#### Linux/macOS

```bash
# 赋予执行权限
chmod +x scripts/multi_agent_test.sh

# 运行测试
./scripts/multi_agent_test.sh
```

#### Windows (PowerShell)

```powershell
# 设置执行策略（如果需要）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行测试
.\scripts\multi_agent_test.ps1
```

**测试内容**：
1. 启动协调者（端口 50051）
2. 启动视觉智能体（端口 50052）
3. 启动 NLP 智能体（端口 50053）
4. 启动机器人智能体（端口 50054）
5. 测试技能调用
6. 测试联邦学习上传
7. 验证合规拦截

---

## 运行维护

### 监控和日志

#### 日志级别

```bash
# Trace - 最详细
clawfed server --log-level trace

# Debug - 调试信息
clawfed server --log-level debug

# Info - 一般信息（默认）
clawfed server --log-level info

# Warn - 警告信息
clawfed server --log-level warn

# Error - 仅错误
clawfed server --log-level error
```

#### 日志格式

```bash
# JSON 格式（结构化，便于解析）
clawfed server --log-format json

# Pretty 格式（人类可读）
clawfed server --log-format pretty
```

#### 日志过滤

```bash
# 使用 jq 过滤 JSON 日志
clawfed server --log-format json | jq 'select(.event == "skill_call")'

# 过滤特定智能体
clawfed server --log-format json | jq 'select(.agent_id == "vision_agent_01")'

# 过滤错误日志
clawfed server --log-format json | jq 'select(.level == "ERROR")'

# 组合过滤
clawfed server --log-format json | jq 'select(.event == "compliance_blocked" or .level == "ERROR")'
```

#### 日志输出到文件

```bash
# 输出到文件
clawfed server --log-format json > server.log 2>&1

# 同时输出到文件和终端
clawfed server --log-format json | tee server.log

# 后台运行并记录日志
nohup clawfed server --log-format json > server.log 2>&1 &
```

#### 结构化日志字段

所有日志包含以下字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `timestamp` | string | ISO 8601 时间戳 |
| `level` | string | 日志级别（TRACE/DEBUG/INFO/WARN/ERROR） |
| `agent_id` | string | 智能体 ID |
| `peer` | string | 对端智能体 ID |
| `event` | string | 事件类型 |
| `status` | string | 状态（started/success/error/blocked） |
| `message` | string | 附加消息 |

#### 关键事件

| 事件 | 说明 | 重要性 |
|------|------|--------|
| `server_start` | 服务器启动 | 高 |
| `agent_register` | 智能体注册 | 高 |
| `skill_call` | 技能调用 | 中 |
| `skill_call_completed` | 技能调用完成 | 中 |
| `compliance_blocked` | 合规拦截 | 高 |
| `fl_upload` | FL 上传 | 高 |
| `fl_upload_complete` | FL 上传完成 | 高 |

### 性能优化

#### 调整并发

```bash
# 设置 Tokio 运行时线程数
export TOKIO_WORKER_THREADS=4
clawfed server

# 或在代码中设置
[build-dependencies]
tokio = { version = "1.35", features = ["rt-multi-thread"] }
```

#### 内存优化

```bash
# 限制堆大小（Linux）
ulimit -v 524288  # 512MB

# 使用 jemalloc 分配器
[dependencies]
jemallocator = "0.5"

# 在 main.rs 中
use jemallocator::Jemalloc;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;
```

#### 网络优化

```bash
# 调整 TCP 缓冲区大小
export TCP_BUFFER_SIZE=65536

# 启用 TCP_NODELAY
export TCP_NODELAY=1
```

### 健康检查

#### 端口检查

```bash
# 检查端口是否监听
netstat -an | grep 50051

# 或使用 lsof
lsof -i :50051

# 或使用 ss
ss -ltn | grep 50051
```

#### 连接测试

```bash
# 测试 gRPC 连接
grpcurl -plaintext localhost:50051 list

# 测试特定服务
grpcurl -plaintext localhost:50051 clawfed.AgentService/ListMethods

# 使用 curl（HTTP/2）
curl -k --http2 https://localhost:50051
```

#### 服务状态

```bash
# 检查进程
ps aux | grep clawfed

# 检查资源使用
top -p $(pgrep clawfed)

# 检查内存使用
pmap $(pgrep clawfed) | tail -1
```

### 备份和恢复

#### 配置备份

```bash
# 备份配置文件
cp clawfed.toml clawfed.toml.backup

# 备份整个配置目录
tar -czf config-backup-$(date +%Y%m%d).tar.gz *.toml
```

#### 日志归档

```bash
# 归档日志
gzip -c server.log > server.log.$(date +%Y%m%d).gz

# 清理旧日志
find . -name "server.log.*.gz" -mtime +30 -delete
```

### 更新和升级

#### 依赖更新

```bash
# 更新所有依赖
cargo update

# 更新特定依赖
cargo update tonic

# 检查安全更新
cargo audit
```

#### 版本升级

```bash
# 更新 Rust 工具链
rustup update

# 更新到最新稳定版
rustup update stable

# 安装特定版本
rustup install 1.75.0
```

---

## 故障排查

### 常见问题

#### 1. 端口被占用

**错误信息**：
```
Error: Os { code: 10048, kind: AddrInUse, message: "Address already in use" }
```

**解决方案**：

Windows:
```bash
# 查找占用端口的进程
netstat -ano | findstr :50051

# 杀死进程
taskkill /PID <PID> /F

# 或使用不同端口
clawfed server --addr "[::1]:50060"
```

Linux/macOS:
```bash
# 查找占用端口的进程
lsof -i :50051

# 杀死进程
kill -9 <PID>

# 或使用不同端口
clawfed server --addr "[::1]:50060"
```

#### 2. 连接被拒绝

**错误信息**：
```
Error: Connection refused
```

**解决方案**：
1. 确保协调者正在运行
2. 检查防火墙设置
3. 验证地址格式（使用 `[::1]` 而不是 `localhost`）
4. 检查网络连接

```bash
# 测试网络连接
ping coordinator.example.com

# 测试端口连通性
telnet coordinator.example.com 50051

# 或使用 nc
nc -zv coordinator.example.com 50051
```

#### 3. 合规拦截

**错误信息**：
```
Error: Compliance check failed: CN-DATA-001
```

**解决方案**：
1. 检查技能名称是否包含敏感词
2. 检查任务 ID 是否包含敏感词
3. 修改配置文件中的 `country` 设置
4. 使用合规的技能名称和任务 ID

**敏感词列表**：
- 技能调用：`face`, `raw`, `id_card`, `generate`
- FL 任务：`biometric`, `portrait`

#### 4. 文件未找到

**错误信息**：
```
Error: File not found: delta.lora
```

**解决方案**：
```bash
# 检查文件是否存在
ls -la delta.lora

# 使用绝对路径
clawfed fl upload-delta --task grasping_v1 --file /path/to/delta.lora

# 检查文件权限
chmod 644 delta.lora
```

#### 5. 编译错误

**错误信息**：
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

# 检查 Rust 版本
rustc --version

# 更新 Rust 工具链
rustup update
```

#### 6. 内存不足

**错误信息**：
```
Error: Out of memory
```

**解决方案**：
```bash
# 增加交换空间
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 或限制内存使用
ulimit -v 524288  # 512MB
```

### 调试技巧

#### 启用详细日志

```bash
# 启用 trace 级别日志
clawfed server --log-level trace --log-format json

# 启用 RUST_BACKTRACE
RUST_BACKTRACE=1 clawfed server

# 启用完整回溯
RUST_BACKTRACE=full clawfed server
```

#### 使用调试器

```bash
# 使用 lldb (LLVM)
lldb target/debug/clawfed server

# 使用 gdb (GNU)
gdb target/debug/clawfed server

# 在 VS Code 中调试
# 创建 .vscode/launch.json
{
  "type": "lldb",
  "request": "launch",
  "name": "Debug clawfed",
  "cargo": {
    "args": ["build", "--bin=clawfed"],
    "filter": {
      "name": "clawfed",
      "kind": "bin"
    }
  },
  "args": ["server"],
  "cwd": "${workspaceFolder}"
}
```

#### 性能分析

```bash
# 使用 flamegraph
cargo install flamegraph
cargo flamegraph --bin clawfed -- server

# 使用 perf (Linux)
perf record -g ./target/release/clawfed server
perf report

# 使用 Instruments (macOS)
instruments -t "Time Profiler" ./target/release/clawfed server
```

---

## 生产环境部署

### systemd 服务 (Linux)

#### 创建服务文件

创建 `/etc/systemd/system/clawfed-coordinator.service`:

```ini
[Unit]
Description=Clawfed Coordinator
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=clawfed
Group=clawfed
WorkingDirectory=/opt/clawfed
ExecStart=/opt/clawfed/clawfed server --addr "[::1]:50051"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clawfed

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/clawfed

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=512M

[Install]
WantedBy=multi-user.target
```

#### 启动和管理服务

```bash
# 重新加载 systemd
sudo systemctl daemon-reload

# 启用服务（开机自启）
sudo systemctl enable clawfed-coordinator

# 启动服务
sudo systemctl start clawfed-coordinator

# 查看状态
sudo systemctl status clawfed-coordinator

# 查看日志
sudo journalctl -u clawfed-coordinator -f

# 重启服务
sudo systemctl restart clawfed-coordinator

# 停止服务
sudo systemctl stop clawfed-coordinator

# 禁用服务
sudo systemctl disable clawfed-coordinator
```

### Docker 部署

#### Dockerfile

```dockerfile
# 构建阶段
FROM rust:1.75 as builder

WORKDIR /app

# 安装依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制源代码
COPY . .

# 构建
RUN cargo build --release

# 运行阶段
FROM debian:bookworm-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 创建用户
RUN useradd -m -u 1000 clawfed

# 复制二进制文件
COPY --from=builder /app/target/release/clawfed /usr/local/bin/

# 创建工作目录
RUN mkdir -p /var/lib/clawfed && \
    chown -R clawfed:clawfed /var/lib/clawfed

# 切换用户
USER clawfed
WORKDIR /var/lib/clawfed

# 暴露端口
EXPOSE 50051

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD grpcurl -plaintext localhost:50051 clawfed.AgentService/ListMethods || exit 1

# 启动命令
CMD ["clawfed", "server"]
```

#### 构建和运行

```bash
# 构建镜像
docker build -t clawfed:latest .

# 运行容器
docker run -d \
  --name clawfed-coordinator \
  -p 50051:50051 \
  -v /var/lib/clawfed:/var/lib/clawfed \
  clawfed:latest

# 查看日志
docker logs -f clawfed-coordinator

# 进入容器
docker exec -it clawfed-coordinator bash

# 停止容器
docker stop clawfed-coordinator

# 删除容器
docker rm clawfed-coordinator
```

### Docker Compose

创建 `docker-compose.yml`:

```yaml
version: '3.8'

services:
  coordinator:
    image: clawfed:latest
    container_name: clawfed-coordinator
    command: server --addr "[::1]:50051"
    ports:
      - "50051:50051"
    volumes:
      - ./config:/var/lib/clawfed/config
      - ./logs:/var/log/clawfed
    environment:
      - RUST_LOG=info
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "grpcurl", "-plaintext", "localhost:50051", "clawfed.AgentService/ListMethods"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  vision-agent:
    image: clawfed:latest
    container_name: clawfed-vision-agent
    command: agent --server --addr "[::1]:50052"
    ports:
      - "50052:50052"
    depends_on:
      coordinator:
        condition: service_healthy
    environment:
      - RUST_LOG=info
      - COORDINATOR_ADDR=http://coordinator:50051
    restart: unless-stopped

  nlp-agent:
    image: clawfed:latest
    container_name: clawfed-nlp-agent
    command: agent --server --addr "[::1]:50053"
    ports:
      - "50053:50053"
    depends_on:
      coordinator:
        condition: service_healthy
    environment:
      - RUST_LOG=info
      - COORDINATOR_ADDR=http://coordinator:50051
    restart: unless-stopped

  robot-agent:
    image: clawfed:latest
    container_name: clawfed-robot-agent
    command: agent --server --addr "[::1]:50054"
    ports:
      - "50054:50054"
    depends_on:
      coordinator:
        condition: service_healthy
    environment:
      - RUST_LOG=info
      - COORDINATOR_ADDR=http://coordinator:50051
    restart: unless-stopped

volumes:
  config:
  logs:
```

#### 启动和管理

```bash
# 启动所有服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart coordinator

# 停止所有服务
docker-compose down

# 停止并删除卷
docker-compose down -v

# 扩展服务
docker-compose up -d --scale vision-agent=3
```

### Kubernetes 部署

#### Coordinator 部署

创建 `k8s/coordinator-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clawfed-coordinator
  labels:
    app: clawfed-coordinator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clawfed-coordinator
  template:
    metadata:
      labels:
        app: clawfed-coordinator
    spec:
      containers:
      - name: coordinator
        image: clawfed:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 50051
          name: grpc
        env:
        - name: RUST_LOG
          value: "info"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - grpcurl
            - -plaintext
            - localhost:50051
            - clawfed.AgentService/ListMethods
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          exec:
            command:
            - grpcurl
            - -plaintext
            - localhost:50051
            - clawfed.AgentService/ListMethods
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: clawfed-coordinator
spec:
  selector:
    app: clawfed-coordinator
  ports:
  - port: 50051
    targetPort: 50051
    name: grpc
  type: ClusterIP
```

#### 部署和管理

```bash
# 部署
kubectl apply -f k8s/coordinator-deployment.yaml

# 查看状态
kubectl get pods -l app=clawfed-coordinator

# 查看日志
kubectl logs -f deployment/clawfed-coordinator

# 扩展
kubectl scale deployment/clawfed-coordinator --replicas=3

# 更新镜像
kubectl set image deployment/clawfed-coordinator coordinator=clawfed:v2.0.0

# 删除
kubectl delete -f k8s/coordinator-deployment.yaml
```

### 安全加固

#### TLS 配置

```bash
# 生成自签名证书
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes

# 启用 TLS
cargo build --features tls
clawfed server --tls-cert server.crt --tls-key server.key
```

#### 防火墙规则

```bash
# UFW (Ubuntu)
sudo ufw allow 50051/tcp
sudo ufw allow from 192.168.1.0/24 to any port 50051
sudo ufw enable

# iptables
sudo iptables -A INPUT -p tcp --dport 50051 -j ACCEPT
sudo iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 50051 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

#### SELinux 配置

```bash
# 允许网络访问
sudo setsebool -P httpd_can_network_connect 1

# 创建策略
sudo semanage fcontext -a -t httpd_sys_content_t "/var/lib/clawfed(/.*)?"
sudo restorecon -R -v /var/lib/clawfed
```

### 监控和告警

#### Prometheus 集成

```rust
// 添加 prometheus 依赖
[dependencies]
prometheus = "0.13"

// 在代码中集成
use prometheus::{Counter, Histogram, Registry};

lazy_static! {
    static ref REGISTRY: Registry = Registry::new();
    static ref SKILL_CALLS: Counter = Counter::new(
        "skill_calls_total",
        "Total number of skill calls"
    ).unwrap();
    static ref SKILL_DURATION: Histogram = Histogram::new(
        "skill_call_duration_seconds",
        "Skill call duration in seconds"
    ).unwrap();
}
```

#### Grafana 仪表板

创建监控面板，监控以下指标：
- 请求速率
- 响应时间
- 错误率
- 内存使用
- CPU 使用
- 网络流量

#### 告警规则

```yaml
groups:
- name: clawfed
  rules:
  - alert: HighErrorRate
    expr: rate(clawfed_errors_total[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"

  - alert: HighMemoryUsage
    expr: process_resident_memory_bytes{job="clawfed"} > 500 * 1024 * 1024
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "Memory usage exceeds 500MB"
```

---

## 附录

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `RUST_LOG` | 日志级别 | `info` |
| `TOKIO_WORKER_THREADS` | Tokio 线程数 | CPU 核心数 |
| `CLAWFED_ADDR` | 服务器地址 | `[::1]:50051` |
| `CLAWFED_AGENT_ID` | 智能体 ID | `coordinator` |
| `CLAWFED_CONFIG` | 配置文件路径 | `./clawfed.toml` |

### 端口分配

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| Coordinator | 50051 | 协调者服务 |
| Vision Agent | 50052 | 视觉智能体 |
| NLP Agent | 50053 | NLP 智能体 |
| Robot Agent | 50054 | 机器人智能体 |

### 性能基准

| 指标 | 目标值 | 说明 |
|------|---------|------|
| 内存使用 | ≤ 50MB | Jetson Orin 测试 |
| 响应时间 | < 100ms | 技能调用延迟 |
| 吞吐量 | > 1000 req/s | 单节点性能 |
| 启动时间 | < 5s | 冷启动时间 |

### 依赖数量

- **总依赖数**: < 30 crates（不含 dev-dependencies）
- **直接依赖**: ~15 crates
- **传递依赖**: ~30 crates

### 许可证

OpenClaw Internal Use Only

---

## 相关文档

- [README.md](README.md) - 项目概述和快速开始
- [DEPLOYMENT.md](DEPLOYMENT.md) - 多智能体部署指南
- [USAGE.md](USAGE.md) - CLI 使用示例
- [clawfed.toml](clawfed.toml) - 配置文件示例

---

**文档版本**: 1.0.0
**最后更新**: 2026-03-31
**维护者**: OpenClaw Team
