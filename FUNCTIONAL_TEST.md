# Clawfed 功能测试指南

**文档版本**: 1.0.0
**最后更新**: 2026-03-31
**测试范围**: 功能完整性验证和可用性测试

---

## 📋 目录

- [测试环境准备](#测试环境准备)
- [单元测试](#单元测试)
- [集成测试](#集成测试)
- [功能验证清单](#功能验证清单)
- [手动测试步骤](#手动测试步骤)
- [自动化测试脚本](#自动化测试脚本)
- [测试报告](#测试报告)

---

## 测试环境准备

### 1. 系统要求

- **操作系统**: Windows, Linux, 或 macOS
- **Rust 版本**: 1.75 或更高
- **内存**: 至少 2GB RAM
- **磁盘空间**: 至少 500MB 可用空间

### 2. 安装依赖

```bash
# 安装 Rust 工具链（如果尚未安装）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 验证安装
rustc --version
cargo --version

# 安装 grpcurl（用于 gRPC 测试）
# macOS
brew install grpcurl

# Linux
sudo apt-get install grpcurl

# Windows
# 从 https://github.com/fullstorydev/grpcurl/releases 下载
```

### 3. 编译项目

```bash
# 克隆项目（如果需要）
cd clawfed

# 开发构建
cargo build

# 发布构建（推荐用于测试）
cargo build --release

# 验证二进制文件
./target/release/clawfed --help
```

---

## 单元测试

### 1. 运行所有单元测试

```bash
# 运行所有测试
cargo test

# 运行测试并显示输出
cargo test -- --nocapture

# 运行特定模块的测试
cargo test skill
cargo test compliance
cargo test fl

# 运行特定测试
cargo test test_skill_execution
cargo test test_compliance_cn_blocking
```

### 2. 单元测试清单

| 测试模块 | 测试数量 | 状态 | 说明 |
|---------|---------|------|------|
| skill/mod.rs | 4 | ✅ | 技能创建、执行、注册 |
| net/compliance.rs | 5 | ✅ | 合规检查、CN 地区规则 |
| fl/mod.rs | 3 | ✅ | FL 上传、文件验证 |
| net/server.rs | 3 | ✅ | 智能体注册、发现 |
| cli/mod.rs | 2 | ✅ | CLI 解析 |
| cli/fl.rs | 3 | ✅ | FL 命令处理 |

### 3. 预期结果

所有测试应该通过，输出类似：

```
running 20 tests
test skill::tests::test_skill_creation ... ok
test skill::tests::test_skill_execution ... ok
test skill::tests::test_skill_registry ... ok
test skill::tests::test_default_skills ... ok
test compliance::tests::test_compliance_disabled ... ok
test compliance::tests::test_compliance_cn_skill_blocking ... ok
test compliance::tests::test_compliance_cn_fl_blocking ... ok
test compliance::tests::test_compliance_non_cn ... ok
test compliance::tests::test_compliance_custom_rules ... ok
test fl::tests::test_file_validation_lora ... ok
test fl::tests::test_file_validation_delta ... ok
test fl::tests::test_file_validation_invalid ... ok
test server::tests::test_agent_registry ... ok
test server::tests::test_agent_discovery ... ok
test server::tests::test_fl_task_management ... ok
test cli::tests::test_cli_parsing ... ok
test cli::tests::test_cli_invalid_command ... ok
test fl::tests::test_upload_delta_command_success ... ok
test fl::tests::test_upload_delta_command_file_not_found ... ok
test fl::tests::test_upload_delta_command_compliance_blocked ... ok

test result: ok. 20 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

---

## 集成测试

### 1. 多智能体协作测试

#### 测试目标
- 验证协调者服务器启动
- 验证智能体注册
- 验证技能调用
- 验证联邦学习上传
- 验证合规拦截

#### 测试步骤

**步骤 1: 启动协调者**

```bash
# 终端 1
./target/release/clawfed server --addr "[::1]:50051" --agent-id coordinator --log-level info

# 预期输出
✓ Coordinator server starting on [::1]:50051
  Agent ID: coordinator
  Press Ctrl+C to stop
```

**步骤 2: 启动视觉智能体**

```bash
# 终端 2
./target/release/clawfed agent --server --addr "[::1]:50052" --log-level info

# 预期输出
✓ Agent starting in server mode on [::1]:50052
  Agent ID: agent_01
  Press Ctrl+C to stop
```

**步骤 3: 启动 NLP 智能体**

```bash
# 终端 3
./target/release/clawfed agent --server --addr "[::1]:50053" --log-level info

# 预期输出
✓ Agent starting in server mode on [::1]:50053
  Agent ID: agent_01
  Press Ctrl+C to stop
```

**步骤 4: 测试技能调用**

```bash
# 终端 4
./target/release/clawfed call agent_01 detect_objects \
  --args '{"url": "https://example.com/image.jpg"}' \
  --addr "http://[::1]:50051"

# 预期输出
✓ Called skill 'detect_objects' on agent 'agent_01'
  Result: {"objects":[{"class":"person","confidence":0.95},{"class":"car","confidence":0.87}],"count":2}
```

**步骤 5: 测试联邦学习上传**

```bash
# 创建测试文件
echo -e "\x4C\x6F\x52\x41\x00\x01" > test.lora

# 上传 Delta
./target/release/clawfed fl upload-delta \
  --task grasping_v1 \
  --file test.lora \
  --coordinator "http://[::1]:50051"

# 预期输出
✓ Delta uploaded successfully to task: grasping_v1
```

**步骤 6: 测试合规拦截**

```bash
# 测试敏感技能调用
./target/release/clawfed call agent_01 face_recognition \
  --args '{"image": "test.jpg"}' \
  --addr "http://[::1]:50051"

# 预期输出（应该被拦截）
Error: Compliance check failed: CN-SKILL-001: Skill 'face_recognition' is not allowed in CN region
```

### 2. 自动化测试脚本

#### Linux/macOS

```bash
# 赋予执行权限
chmod +x scripts/multi_agent_test.sh

# 运行测试
./scripts/multi_agent_test.sh
```

#### Windows (PowerShell)

```powershell
# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行测试
.\scripts\multi_agent_test.ps1
```

---

## 功能验证清单

### 1. 核心功能验证

#### 1.1 智能体管理

| 功能 | 测试命令 | 预期结果 | 状态 |
|------|---------|---------|------|
| 启动协调者 | `clawfed server` | 服务器启动成功 | ⬜ |
| 启动智能体 | `clawfed agent --server` | 智能体启动成功 | ⬜ |
| 智能体注册 | 自动 | 注册到协调者 | ⬜ |
| 智能体发现 | `clawfed call` | 发现目标智能体 | ⬜ |

#### 1.2 技能系统

| 功能 | 测试命令 | 预期结果 | 状态 |
|------|---------|---------|------|
| 技能注册 | 自动 | 技能注册成功 | ⬜ |
| 技能调用 | `clawfed call agent detect_objects` | 返回正确结果 | ⬜ |
| 技能参数传递 | `--args '{"url":"..."}'` | 参数正确传递 | ⬜ |
| 技能错误处理 | 无效技能 | 返回错误信息 | ⬜ |

#### 1.3 联邦学习

| 功能 | 测试命令 | 预期结果 | 状态 |
|------|---------|---------|------|
| Delta 上传 | `clawfed fl upload-delta` | 上传成功 | ⬜ |
| 文件验证 | 无效文件格式 | 返回错误 | ⬜ |
| 文件大小检查 | 超大文件 | 返回错误 | ⬜ |
| 任务管理 | 自动 | 任务创建成功 | ⬜ |

#### 1.4 合规性

| 功能 | 测试命令 | 预期结果 | 状态 |
|------|---------|---------|------|
| CN 地区技能拦截 | 调用敏感技能 | 拦截并返回错误 | ⬜ |
| CN 地区 FL 拦截 | 上传敏感任务 | 拦截并返回错误 | ⬜ |
| 非地区限制 | 正常操作 | 允许执行 | ⬜ |

#### 1.5 网络通信

| 功能 | 测试命令 | 预期结果 | 状态 |
|------|---------|---------|------|
| gRPC 连接 | 自动 | 连接成功 | ⬜ |
| 消息序列化 | 自动 | 正确序列化 | ⬜ |
| 错误处理 | 网络错误 | 正确处理 | ⬜ |
| 超时处理 | 无响应 | 超时返回 | ⬜ |

#### 1.6 CLI 命令

| 功能 | 测试命令 | 预期结果 | 状态 |
|------|---------|---------|------|
| 帮助信息 | `clawfed --help` | 显示帮助 | ⬜ |
| 命令解析 | 所有命令 | 正确解析 | ⬜ |
| 日志级别 | `--log-level debug` | 正确设置 | ⬜ |
| 日志格式 | `--log-format json` | 正确格式 | ⬜ |

### 2. 性能验证

| 指标 | 目标值 | 测试方法 | 状态 |
|------|--------|---------|------|
| 内存使用 | ≤ 50MB | 系统监控 | ⬜ |
| 响应时间 | < 100ms | 时间测量 | ⬜ |
| 启动时间 | < 5s | 时间测量 | ⬜ |
| 并发处理 | > 100 req/s | 压力测试 | ⬜ |

---

## 手动测试步骤

### 测试 1: 基本功能测试

#### 目标
验证基本功能是否正常工作

#### 步骤

1. **编译项目**
   ```bash
   cargo build --release
   ```

2. **验证 CLI**
   ```bash
   ./target/release/clawfed --help
   ```
   预期：显示帮助信息

3. **启动协调者**
   ```bash
   ./target/release/clawfed server --log-level info
   ```
   预期：服务器启动，显示绑定地址

4. **验证端口监听**
   ```bash
   # Linux/macOS
   netstat -an | grep 50051

   # Windows
   netstat -an | findstr 50051
   ```
   预期：端口 50051 正在监听

#### 通过标准
- ✅ 项目编译成功
- ✅ CLI 帮助信息正确显示
- ✅ 协调者服务器启动成功
- ✅ 端口正确监听

---

### 测试 2: 智能体注册测试

#### 目标
验证智能体注册功能

#### 步骤

1. **启动协调者**（如果未启动）
   ```bash
   ./target/release/clawfed server --log-level info
   ```

2. **启动智能体**
   ```bash
   ./target/release/clawfed agent --server --log-level info
   ```

3. **检查日志**
   - 协调者日志应显示智能体注册
   - 智能体日志应显示启动成功

#### 通过标准
- ✅ 智能体成功启动
- ✅ 智能体注册到协调者
- ✅ 日志显示正确的事件

---

### 测试 3: 技能调用测试

#### 目标
验证技能调用功能

#### 步骤

1. **确保协调者和智能体正在运行**

2. **调用技能**
   ```bash
   ./target/release/clawfed call agent_01 detect_objects \
     --args '{"url": "https://example.com/image.jpg"}' \
     --addr "http://[::1]:50051"
   ```

3. **验证结果**
   - 应返回检测到的对象
   - 日志应显示技能调用事件

#### 通过标准
- ✅ 技能调用成功
- ✅ 返回正确结果
- ✅ 日志记录完整

---

### 测试 4: 联邦学习测试

#### 目标
验证联邦学习功能

#### 步骤

1. **创建测试文件**
   ```bash
   echo -e "\x4C\x6F\x52\x41\x00\x01" > test.lora
   ```

2. **上传 Delta**
   ```bash
   ./target/release/clawfed fl upload-delta \
     --task grasping_v1 \
     --file test.lora \
     --coordinator "http://[::1]:50051"
   ```

3. **验证结果**
   - 应显示上传成功
   - 日志应显示上传事件

#### 通过标准
- ✅ Delta 上传成功
- ✅ 文件验证通过
- ✅ 任务创建成功

---

### 测试 5: 合规性测试

#### 目标
验证合规性检查

#### 步骤

1. **测试敏感技能调用**
   ```bash
   ./target/release/clawfed call agent_01 face_recognition \
     --args '{"image": "test.jpg"}' \
     --addr "http://[::1]:50051"
   ```

2. **测试敏感 FL 任务**
   ```bash
   ./target/release/clawfed fl upload-delta \
     --task biometric_task \
     --file test.lora \
     --coordinator "http://[::1]:50051"
   ```

3. **验证结果**
   - 两个操作都应该被拦截
   - 应返回合规错误

#### 通过标准
- ✅ 敏感技能被拦截
- ✅ 敏感 FL 任务被拦截
- ✅ 返回正确的错误信息

---

### 测试 6: 错误处理测试

#### 目标
验证错误处理

#### 步骤

1. **测试无效技能**
   ```bash
   ./target/release/clawfed call agent_01 invalid_skill \
     --args '{}' \
     --addr "http://[::1]:50051"
   ```

2. **测试无效文件**
   ```bash
   ./target/release/clawfed fl upload-delta \
     --task grasping_v1 \
     --file nonexistent.lora \
     --coordinator "http://[::1]:50051"
   ```

3. **测试无效地址**
   ```bash
   ./target/release/clawfed call agent_01 detect_objects \
     --args '{}' \
     --addr "http://[::1]:99999"
   ```

#### 通过标准
- ✅ 所有错误都被正确处理
- ✅ 返回有意义的错误信息
- ✅ 程序不会崩溃

---

### 测试 7: 日志功能测试

#### 目标
验证日志功能

#### 步骤

1. **测试 JSON 格式日志**
   ```bash
   ./target/release/clawfed server --log-format json
   ```

2. **测试 Pretty 格式日志**
   ```bash
   ./target/release/clawfed server --log-format pretty
   ```

3. **测试不同日志级别**
   ```bash
   ./target/release/clawfed server --log-level debug
   ./target/release/clawfed server --log-level trace
   ./target/release/clawfed server --log-level warn
   ```

#### 通过标准
- ✅ JSON 格式正确
- ✅ Pretty 格式可读
- ✅ 日志级别正确过滤

---

### 测试 8: 并发测试

#### 目标
验证并发处理能力

#### 步骤

1. **启动协调者和多个智能体**

2. **并发调用技能**
   ```bash
   # Linux/macOS
   for i in {1..10}; do
     ./target/release/clawfed call agent_01 detect_objects \
       --args '{"url":"test.jpg"}' \
       --addr "http://[::1]:50051" &
   done
   wait

   # Windows (PowerShell)
   1..10 | ForEach-Object {
     Start-Job -ScriptBlock {
       & "./target/release/clawfed" call agent_01 detect_objects `
         --args '{"url":"test.jpg"}' `
         --addr "http://[::1]:50051"
     }
   }
   ```

3. **监控性能**
   - 观察响应时间
   - 检查是否有错误

#### 通过标准
- ✅ 所有请求都成功处理
- ✅ 响应时间在可接受范围内
- ✅ 没有资源泄漏

---

## 自动化测试脚本

### 完整测试脚本 (Linux/macOS)

```bash
#!/bin/bash
# Clawfed 完整功能测试脚本

set -e

echo "=== Clawfed 功能测试 ==="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 测试计数器
PASSED=0
FAILED=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected="$3"

    echo -n "测试: $test_name ... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}通过${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}失败${NC}"
        ((FAILED++))
        return 1
    fi
}

# 1. 编译测试
echo "=== 1. 编译测试 ==="
run_test "项目编译" "cargo build --release" ""

# 2. 单元测试
echo ""
echo "=== 2. 单元测试 ==="
run_test "运行单元测试" "cargo test --quiet" ""

# 3. CLI 测试
echo ""
echo "=== 3. CLI 测试 ==="
run_test "CLI 帮助" "./target/release/clawfed --help" ""
run_test "CLI 版本" "./target/release/clawfed --version" ""

# 4. 功能测试
echo ""
echo "=== 4. 功能测试 ==="

# 创建测试文件
echo -e "\x4C\x6F\x52\x41\x00\x01" > /tmp/test.lora

# 测试总结
echo ""
echo "=== 测试总结 ==="
echo -e "通过: ${GREEN}${PASSED}${NC}"
echo -e "失败: ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}部分测试失败！${NC}"
    exit 1
fi
```

### 完整测试脚本 (Windows PowerShell)

```powershell
# Clawfed 完整功能测试脚本 (PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "=== Clawfed 功能测试 ===" -ForegroundColor Cyan
Write-Host ""

# 测试计数器
$Passed = 0
$Failed = 0

# 测试函数
function Run-Test {
    param(
        [string]$TestName,
        [scriptblock]$TestCommand
    )

    Write-Host -NoNewline "测试: $TestName ... "

    try {
        & $TestCommand | Out-Null
        Write-Host "通过" -ForegroundColor Green
        $script:Passed++
    } catch {
        Write-Host "失败" -ForegroundColor Red
        $script:Failed++
    }
}

# 1. 编译测试
Write-Host "=== 1. 编译测试 ===" -ForegroundColor Cyan
Run-Test "项目编译" { cargo build --release }

# 2. 单元测试
Write-Host ""
Write-Host "=== 2. 单元测试 ===" -ForegroundColor Cyan
Run-Test "运行单元测试" { cargo test --quiet }

# 3. CLI 测试
Write-Host ""
Write-Host "=== 3. CLI 测试 ===" -ForegroundColor Cyan
Run-Test "CLI 帮助" { .\target\release\clawfed --help }
Run-Test "CLI 版本" { .\target\release\clawfed --version }

# 4. 功能测试
Write-Host ""
Write-Host "=== 4. 功能测试 ===" -ForegroundColor Cyan

# 创建测试文件
$bytes = [byte[]](0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01)
[System.IO.File]::WriteAllBytes("$env:TEMP\test.lora", $bytes)

# 测试总结
Write-Host ""
Write-Host "=== 测试总结 ===" -ForegroundColor Cyan
Write-Host "通过: $Passed" -ForegroundColor Green
Write-Host "失败: $Failed" -ForegroundColor Red
Write-Host ""

if ($Failed -eq 0) {
    Write-Host "所有测试通过！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "部分测试失败！" -ForegroundColor Red
    exit 1
}
```

---

## 测试报告

### 测试报告模板

```markdown
# Clawfed 功能测试报告

**测试日期**: YYYY-MM-DD
**测试人员**: [姓名]
**测试环境**: [操作系统/版本]
**项目版本**: [版本号]

---

## 测试摘要

| 类别 | 总数 | 通过 | 失败 | 通过率 |
|------|------|------|------|--------|
| 单元测试 | 20 | 20 | 0 | 100% |
| 集成测试 | 8 | 8 | 0 | 100% |
| 功能测试 | 6 | 6 | 0 | 100% |
| **总计** | **34** | **34** | **0** | **100%** |

---

## 详细测试结果

### 1. 单元测试

| 测试 | 状态 | 备注 |
|------|------|------|
| test_skill_creation | ✅ 通过 | |
| test_skill_execution | ✅ 通过 | |
| ... | ... | |

### 2. 集成测试

| 测试 | 状态 | 备注 |
|------|------|------|
| 基本功能测试 | ✅ 通过 | |
| 智能体注册测试 | ✅ 通过 | |
| ... | ... | |

### 3. 功能测试

| 功能 | 状态 | 备注 |
|------|------|------|
| 智能体管理 | ✅ 通过 | |
| 技能系统 | ✅ 通过 | |
| 联邦学习 | ✅ 通过 | |
| 合规性 | ✅ 通过 | |
| 网络通信 | ✅ 通过 | |
| CLI 命令 | ✅ 通过 | |

---

## 性能测试结果

| 指标 | 目标值 | 实际值 | 状态 |
|------|--------|--------|------|
| 内存使用 | ≤ 50MB | 45MB | ✅ |
| 响应时间 | < 100ms | 85ms | ✅ |
| 启动时间 | < 5s | 3.2s | ✅ |
| 并发处理 | > 100 req/s | 120 req/s | ✅ |

---

## 发现的问题

### 严重问题
无

### 一般问题
无

### 轻微问题
无

---

## 改进建议

1. 添加更多集成测试用例
2. 添加性能基准测试
3. 完善文档注释

---

## 结论

所有测试通过，项目功能完整，可以正常使用。

**测试状态**: ✅ 通过
**推荐部署**: 是
```

---

## 常见问题

### Q1: 测试失败怎么办？

**A**: 检查以下几点：
1. 确保 Rust 版本 ≥ 1.75
2. 确保所有依赖已正确安装
3. 检查端口是否被占用
4. 查看详细错误信息

### Q2: 如何调试测试失败？

**A**:
1. 使用 `--nocapture` 查看测试输出
2. 使用 `-- --test-threads=1` 顺序运行测试
3. 使用 `RUST_BACKTRACE=1` 查看堆栈跟踪
4. 检查日志文件

### Q3: 性能不达标怎么办？

**A**:
1. 使用 `cargo build --release` 构建优化版本
2. 检查系统资源使用情况
3. 调整并发参数
4. 优化网络配置

---

## 附录

### A. 测试环境配置示例

```toml
# clawfed.toml
[agent]
id = "test_agent"
address = "127.0.0.1"
port = 50052

[compliance]
enabled = true
country = "CN"

[fl]
max_upload_mb = 10

[logging]
level = "info"
format = "json"
```

### B. 测试数据

**测试技能参数**:
```json
{
  "url": "https://example.com/image.jpg"
}
```

**测试 Delta 文件**:
```
LoRA 格式: 0x4C 0x6F 0x52 0x41 0x00 0x01
DELTA 格式: 0x44 0x45 0x4C 0x54 0x41 0x00
```

---

**文档版本**: 1.0.0
**最后更新**: 2026-03-31
**维护者**: OpenClaw Team
