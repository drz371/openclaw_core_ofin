# 🎯 OpenClaw - 联邦协作框架

**让你在 30 秒内启动多个 AI Agent 并让它们互相协作！**

## 📌 一句话介绍

OpenClaw 是一个轻量级、安全、合规的多 Agent 联邦协作框架。你可以同时启动多个 AI Agent（视觉Agent、文本Agent、机器人Agent等），让它们通过 gRPC 互相调用技能，完成复杂任务。

---

## 🚀 5 分钟快速开始（立即可用）

### 第一步：安装 Rust（如果没有）

**macOS / Linux：**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**Windows：**
去 https://rustup.rs 下载安装

**验证安装：**
```bash
rustc --version
cargo --version
```

### 第二步：编译项目（一键）

```bash
git clone https://github.com/drz371/openclaw_core_ofin.git
cd openclaw_core_ofin
cargo build --release
```

> 💡 编译完成后，可执行文件在 `./target/release/clawfed`

### 第三步：启动测试（30秒体验）

```bash
# 方式 A：一键启动所有 Agent 并测试（推荐）
chmod +x scripts/multi_agent_test.sh
./scripts/multi_agent_test.sh

# 方式 B：20分钟稳定性测试
chmod +x scripts/stability_test_20min.sh
./scripts/stability_test_20min.sh
```

**或者手动启动（3个终端）：**

```bash
# === 终端 1：启动协调器（总控中心）===
./target/release/clawfed server --addr "0.0.0.0:50051" --agent-id coordinator

# === 终端 2：启动视觉 Agent ===
./target/release/clawfed agent --server --addr "0.0.0.0:50052"

# === 终端 3：调用 Agent 技能 ===
./target/release/clawfed call agent_01 detect_objects \
  --addr "http://127.0.0.1:50052" \
  --args '{"url": "https://example.com/image.jpg"}'
```

**成功输出示例：**
```
Called skill: detect_objects
Result: {"status":"success","detections":[{"class":"person","confidence":0.95},{"class":"car","confidence":0.87}]}
```

---

## 📖 完整使用指南

### 命令一览表

| 命令 | 作用 | 示例 |
|------|------|------|
| `clawfed server` | 启动协调器（总控中心） | `clawfed server --addr "0.0.0.0:50051"` |
| `clawfed agent` | 启动 Agent（工作者） | `clawfed agent --server --addr "0.0.0.0:50052"` |
| `clawfed call` | 调用 Agent 技能 | `clawfed call agent_01 detect_objects --args '{}'` |
| `clawfed fl` | 联邦学习操作 | `clawfed fl upload-delta --task xxx --file xxx` |
| `clawfed --help` | 查看帮助 | `clawfed --help` |

---

### 🔧 详细命令说明

#### 1. 启动协调器（Server）

协调器是总控中心，所有 Agent 都向它注册。

```bash
# 基本启动
./target/release/clawfed server

# 自定义地址和 ID
./target/release/clawfed server --addr "0.0.0.0:50051" --agent-id coordinator

# 查看帮助
./target/release/clawfed server --help
```

**参数说明：**
- `--addr`：监听地址，格式 `IP:端口`
- `--agent-id`：Agent 唯一标识符

#### 2. 启动 Agent（Worker）

Agent 是工作者，提供具体技能（图像识别、文本处理等）。

```bash
# 基本启动（自动注册 detect_objects, summarize_pdf 技能）
./target/release/clawfed agent --server --addr "0.0.0.0:50052"

# 带配置文件启动
./target/release/clawfed agent --config ./clawfed.toml --server --addr "0.0.0.0:50052"

# 查看帮助
./target/release/clawfed agent --help
```

#### 3. 调用 Agent 技能

向指定 Agent 发起技能调用请求。

```bash
# 调用图像识别
./target/release/clawfed call agent_01 detect_objects \
  --addr "http://127.0.0.1:50052" \
  --args '{"url": "https://example.com/image.jpg"}'

# 调用 PDF 摘要
./target/release/clawfed call agent_01 summarize_pdf \
  --addr "http://127.0.0.1:50052" \
  --args '{"file": "report.pdf"}'

# 调用数据处理
./target/release/clawfed call agent_01 process_data \
  --addr "http://127.0.0.1:50052" \
  --args '{"dataset": "train.csv"}'
```

**参数说明：**
- `agent_01`：目标 Agent ID
- `detect_objects`：要调用的技能名
- `--addr`：Agent 服务地址（必须是 http:// 开头）
- `--args`：技能参数（JSON 格式）

#### 4. 联邦学习操作

上传模型增量（LoRA 权重等），不传输原始数据。

```bash
# 上传模型增量
./target/release/clawfed fl upload-delta \
  --task grasping_v1 \
  --file ./my_model.lora \
  --coordinator "http://127.0.0.1:50051"

# 查看支持的 FL 任务
./target/release/clawfed fl list-tasks

# 查看帮助
./target/release/clawfed fl --help
```

---

## ⚙️ 配置文件说明

创建 `clawfed.toml` 来自定义行为：

```toml
# Agent 标识
agent_id = "my_agent"

# 安全设置
[security]
# 信任的 Agent 列表
trusted_agents = ["coordinator"]
# 是否使用国密加密（需要编译时启用 sm-crypto feature）
use_sm_crypto = false

# 合规设置
[compliance]
# 是否启用合规检查
enabled = true
# 适用地区（CN = 中国，会拦截敏感操作）
country = "CN"

# 功能开关
[features]
# 是否启用技能系统
enable_skills = true
# 是否启用联邦学习
enable_fl = false
# 联邦学习最大上传大小（MB）
fl_max_upload_mb = 10
```

---

## 🛡️ 合规规则（中国地区）

当 `compliance.country = "CN"` 时，以下操作会被自动拦截：

### 被拦截的技能调用
包含以下关键词的技能会被拦截：
- `face`（人脸相关）
- `raw`（原始数据）
- `id_card`（身份证相关）
- `generate`（生成类）

**示例：**
```bash
# ❌ 会被拦截（包含 face）
./target/release/clawfed call agent_01 face_detect --addr "http://127.0.0.1:50052" --args '{}'

# 输出：Error: Compliance check failed (CN-DATA-001)
```

### 被拦截的联邦学习任务
包含以下关键词的任务会被拦截：
- `biometric`（生物特征）
- `portrait`（人像相关）

**示例：**
```bash
# ❌ 会被拦截（包含 biometric）
./target/release/clawfed fl upload-delta --task biometric_task --file ./model.lora --coordinator "http://127.0.0.1:50051"

# 输出：Error: Compliance check failed (CN-DATA-001)
```

---

## 🧪 测试指南

### 运行所有测试

```bash
# 编译并运行测试
cargo test

# 只运行单元测试
cargo test --lib

# 只运行集成测试
cargo test --test integration_test

# 运行测试并显示输出
cargo test -- --nocapture
```

### 快速功能测试

```bash
# 方式 1：一键测试脚本
chmod +x scripts/multi_agent_test.sh
./scripts/multi_agent_test.sh

# 方式 2：20分钟稳定性测试
chmod +x scripts/stability_test_20min.sh
./scripts/stability_test_20min.sh
```

### 测试清单

| 测试项 | 命令 | 预期结果 |
|--------|------|----------|
| 协调器启动 | `clawfed server` | ✓ 正常运行 |
| Agent 启动 | `clawfed agent --server` | ✓ 正常运行 |
| 技能调用 | `clawfed call agent_01 detect_objects` | ✓ 返回检测结果 |
| 合规拦截 | `clawfed call agent_01 face_detect` | ✗ 返回 CN-DATA-001 |
| FL 上传 | `clawfed fl upload-delta` | ✓ 上传成功 |
| 稳定性 | 20分钟测试 | ✓ 100%成功率 |

---

## 🔍 调试技巧

### 查看详细日志

```bash
# 调试模式启动
./target/release/clawfed server --log-level debug --log-format json

# 查看实时日志
tail -f logs/stability_test/stability_test_*.log
```

### 检查进程状态

```bash
# 查看端口占用
ss -tlnp | grep 5005

# 查看进程内存占用
ps -o rss= -p $(pgrep clawfed)
```

### 常见问题排查

| 问题 | 解决方案 |
|------|----------|
| 编译失败 | 运行 `rustup update` 更新 Rust |
| 连接被拒绝 | 检查端口是否被占用：`ss -tlnp \| grep 5005` |
| 技能调用失败 | 确认 Agent 已启动并注册 |
| 合规拦截错误 | 这是正常行为，如需关闭修改 `clawfed.toml` 中 `country` |
| 内存占用过高 | 检查是否有内存泄漏，查看 `scripts/stability_test_20min.sh` |

---

## 📁 项目结构

```
openclaw_core_ofin/
├── src/
│   ├── main.rs              # 程序入口
│   ├── cli/                 # 命令行接口
│   │   ├── mod.rs           # 主命令处理
│   │   └── fl.rs            # 联邦学习命令
│   ├── agent/               # Agent 管理
│   │   └── mod.rs           # Agent 生命周期
│   ├── skill/               # 技能系统
│   │   └── mod.rs           # 技能注册与调用
│   ├── fl/                  # 联邦学习
│   │   └── mod.rs           # FL 客户端
│   ├── net/                 # 网络通信
│   │   ├── mod.rs           # 模块导出
│   │   ├── server.rs        # gRPC 服务器
│   │   ├── client.rs        # gRPC 客户端
│   │   ├── compliance.rs    # 合规检查
│   │   └── auth.rs          # 认证加密
│   └── proto/               # 协议定义
│       ├── mod.rs           # Proto 模块
│       └── clawfed.proto    # gRPC 接口定义
├── scripts/
│   ├── multi_agent_test.sh       # 多 Agent 测试脚本（Linux/macOS）
│   ├── multi_agent_test.ps1      # 多 Agent 测试脚本（Windows）
│   └── stability_test_20min.sh   # 20 分钟稳定性测试
├── proto/
│   └── clawfed.proto        # gRPC 接口定义
├── tests/
│   └── integration_test.rs  # 集成测试
├── Cargo.toml               # Rust 项目配置
├── clawfed.toml             # 运行时配置（示例）
└── README.md                # 本文档
```

---

## 📋 技术规格

| 指标 | 数值 |
|------|------|
| 目标内存占用 | ≤ 50MB |
| 最小 Rust 版本 | 1.70+ |
| 依赖 crate 数量 | < 30 |
| gRPC 框架 | Tonic |
| 序列化 | Prost + prost-types |
| 追踪日志 | tracing + tracing-subscriber |

---

## 🎯 快速参考卡

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw 快速参考                         │
├─────────────────────────────────────────────────────────────┤
│  启动协调器:    clawfed server --addr "0.0.0.0:50051"        │
│  启动 Agent:    clawfed agent --server --addr "0.0.0.0:50052"│
│  调用技能:      clawfed call <id> <skill> --addr <url>      │
│  上传模型:      clawfed fl upload-delta --task <task>        │
│  运行测试:      ./scripts/multi_agent_test.sh               │
│  查看帮助:      clawfed --help                               │
├─────────────────────────────────────────────────────────────┤
│  合规地区 CN:   拦截 face/raw/id_card/generate/biometric     │
│  内存目标:      ≤ 50MB                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📞 获取帮助

```bash
# 查看所有命令
./target/release/clawfed --help

# 查看特定命令帮助
./target/release/clawfed server --help
./target/release/clawfed agent --help
./target/release/clawfed call --help
./target/release/clawfed fl --help
```

---

**🎉 开始使用 OpenClaw，让多个 AI Agent 为你协作！**
