# 🎯 OpenClaw - 联邦协作框架

**让你在 30 秒内启动多个 AI Agent 并让它们互相协作！**

## 📌 一句话介绍

OpenClaw 是一个轻量级、安全、合规的多 Agent 联邦协作框架。你可以同时启动 **OpenClaw Agent** 和 **Hermes Agent**，让它们通过 gRPC 互相调用技能，完成复杂任务。

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

### 第二步：克隆并编译项目

```bash
git clone https://github.com/drz371/openclaw_core_ofin.git
cd openclaw_core_ofin
cargo build --release
```

> 💡 编译完成后，可执行文件在 `./target/release/clawfed`

### 第三步：一键启动 OpenClaw × Hermes（推荐）

```bash
# 一键安装运行（自动启动 OpenClaw 和 Hermes 两个 Agent）
bash scripts/install_and_run.sh

# 或者完整的多 Agent 测试
bash scripts/multi_agent_test.sh

# 20分钟稳定性测试
bash scripts/stability_test_20min.sh
```

**或者手动启动（3个终端）：**

```bash
# === 终端 1：启动协调器 ===
./target/release/clawfed server --addr "0.0.0.0:50051" --agent-id coordinator

# === 终端 2：启动 OpenClaw Agent ===
./target/release/clawfed agent --server --addr "0.0.0.0:50052"

# === 终端 3：启动 Hermes Agent ===
./target/release/clawfed agent --server --addr "0.0.0.0:50053"
```

---

## 🤖 OpenClaw × Hermes 多 Agent 模式

默认启动两个互联的 Agent：

| Agent | 端口 | Agent ID | 专长技能 |
|-------|------|----------|----------|
| **OpenClaw** | 50052 | agent_01 | detect_objects, summarize_pdf, process_data |
| **Hermes** | 50053 | agent_02 | analyze_context, generate_response, translate_text |

### 跨 Agent 协作示例

```bash
# OpenClaw 调用 Hermes 的翻译技能
./target/release/clawfed call agent_02 translate_text \
  --addr "http://127.0.0.1:50053" \
  --args '{"text": "Hello", "to": "zh"}'

# Hermes 调用 OpenClaw 的图像识别技能
./target/release/clawfed call agent_01 detect_objects \
  --addr "http://127.0.0.1:50052" \
  --args '{"url": "https://example.com/photo.jpg"}'

# OpenClaw 调用 Hermes 的上下文分析
./target/release/clawfed call agent_02 analyze_context \
  --addr "http://127.0.0.1:50053" \
  --args '{"text": "联邦学习协作测试"}'

# Hermes 调用 OpenClaw 的数据处理
./target/release/clawfed call agent_01 process_data \
  --addr "http://127.0.0.1:50052" \
  --args '{"dataset": "collaboration_data.csv"}'
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

### OpenClaw Agent 技能

```bash
# 图像识别
./target/release/clawfed call agent_01 detect_objects \
  --addr "http://127.0.0.1:50052" \
  --args '{"url": "https://example.com/image.jpg"}'

# PDF 摘要
./target/release/clawfed call agent_01 summarize_pdf \
  --addr "http://127.0.0.1:50052" \
  --args '{"file": "report.pdf"}'

# 数据处理
./target/release/clawfed call agent_01 process_data \
  --addr "http://127.0.0.1:50052" \
  --args '{"dataset": "train.csv"}'
```

### Hermes Agent 技能

```bash
# 上下文分析
./target/release/clawfed call agent_02 analyze_context \
  --addr "http://127.0.0.1:50053" \
  --args '{"text": "Hello world"}'

# 生成响应
./target/release/clawfed call agent_02 generate_response \
  --addr "http://127.0.0.1:50053" \
  --args '{"prompt": "What is AI?"}'

# 文本翻译
./target/release/clawfed call agent_02 translate_text \
  --addr "http://127.0.0.1:50053" \
  --args '{"text": "Hello", "to": "zh"}'
```

---

## ⚙️ 配置文件说明

创建 `clawfed.toml` 来自定义行为：

```toml
# Agent 标识
agent_id = "my_agent"

# 安全设置
[security]
trusted_agents = ["coordinator"]
use_sm_crypto = false

# 合规设置
[compliance]
enabled = true
country = "CN"

# 功能开关
[features]
enable_skills = true
enable_fl = false
fl_max_upload_mb = 10
```

---

## 🛡️ 合规规则（中国地区）

当 `compliance.country = "CN"` 时，以下操作会被自动拦截：

### 被拦截的技能调用
- `face`（人脸相关）
- `raw`（原始数据）
- `id_card`（身份证相关）
- `generate`（生成类）

### 被拦截的联邦学习任务
- `biometric`（生物特征）
- `portrait`（人像相关）

---

## 🧪 测试指南

### 一键测试脚本

```bash
# 方式 1：一键安装运行（推荐新手）
bash scripts/install_and_run.sh

# 方式 2：完整多 Agent 协作测试
bash scripts/multi_agent_test.sh

# 方式 3：20分钟稳定性测试
bash scripts/stability_test_20min.sh
```

### 运行 Rust 测试

```bash
# 所有测试
cargo test

# 单元测试
cargo test --lib

# 集成测试
cargo test --test integration_test
```

### 测试清单

| 测试项 | 命令 | 预期结果 |
|--------|------|----------|
| OpenClaw 技能 | `clawfed call agent_01 detect_objects` | ✓ |
| Hermes 技能 | `clawfed call agent_02 translate_text` | ✓ |
| 跨 Agent 协作 | OpenClaw 调用 Hermes | ✓ |
| 合规拦截 | `clawfed call agent_01 face_detect` | ✗ CN-DATA-001 |
| 稳定性测试 | 20分钟测试 | ✓ 100%成功率 |

---

## 🔍 常见问题排查

| 问题 | 解决方案 |
|------|----------|
| 编译失败 | `rustup update` 更新 Rust |
| 端口被占用 | `ss -tlnp \| grep 5005` 检查端口 |
| 连接被拒绝 | 检查 Agent 是否已启动并注册 |
| 合规拦截错误 | 正常行为，修改 `clawfed.toml` 可关闭 |

---

## 📁 项目结构

```
openclaw_core_ofin/
├── src/
│   ├── main.rs              # 程序入口
│   ├── cli/                 # 命令行接口
│   ├── agent/               # Agent 管理
│   ├── skill/              # 技能系统
│   ├── fl/                 # 联邦学习
│   ├── net/                # 网络通信
│   └── proto/              # 协议定义
├── scripts/
│   ├── install_and_run.sh       # 一键安装运行（OpenClaw × Hermes）
│   ├── multi_agent_test.sh      # 多 Agent 协作测试
│   └── stability_test_20min.sh  # 20分钟稳定性测试
├── proto/
│   └── clawfed.proto        # gRPC 接口定义
├── Cargo.toml               # Rust 项目配置
└── README.md                # 本文档
```

---

## 📋 技术规格

| 指标 | 数值 |
|------|------|
| 目标内存占用 | ≤ 50MB（实测 4MB） |
| 最小 Rust 版本 | 1.75+ |
| gRPC 框架 | Tonic 0.11 |
| 并发支持 | Tokio 异步运行时 |

---

## 🎯 快速参考卡

```
╔═══════════════════════════════════════════════════════════╗
║              OpenClaw × Hermes 快速参考                   ║
╠═══════════════════════════════════════════════════════════╣
║  服务地址:                                                 ║
║    OpenClaw:   http://127.0.0.1:50052 (agent_01)         ║
║    Hermes:     http://127.0.0.1:50053 (agent_02)         ║
║    Coordinator: http://127.0.0.1:50051                   ║
╠═══════════════════════════════════════════════════════════╣
║  启动命令:                                                 ║
║    一键启动:  bash scripts/install_and_run.sh            ║
║    完整测试:  bash scripts/multi_agent_test.sh           ║
║    稳定性:    bash scripts/stability_test_20min.sh       ║
╠═══════════════════════════════════════════════════════════╣
║  合规地区 CN:  拦截 face/raw/id_card/generate/biometric  ║
║  内存目标:    ≤ 50MB (实测 4MB)                          ║
╚═══════════════════════════════════════════════════════════╝
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

**🎉 开始使用 OpenClaw × Hermes，让多个 AI Agent 为你协作！**
