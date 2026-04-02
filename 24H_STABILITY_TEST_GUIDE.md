# OpenClaw 24小时稳定性测试使用指南

**文档版本**: 1.0.0  
**创建日期**: 2026-03-31  
**测试类型**: 24小时稳定性测试

---

## 📋 目录

- [测试概述](#测试概述)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [测试脚本说明](#测试脚本说明)
- [监控测试](#监控测试)
- [生成报告](#生成报告)
- [故障排查](#故障排查)

---

## 测试概述

OpenClaw 24小时稳定性测试旨在验证系统在长时间运行下的稳定性和可靠性。测试模拟了多Agent协作场景，包括：

- **技能调用**: Agent之间的远程技能调用
- **联邦学习**: 模型增量上传和聚合
- **合规检查**: 不同区域的合规性验证
- **混合操作**: 组合多种操作的复杂场景

### 测试架构

```
┌─────────────────────────────────────────────────┐
│         OpenClaw Stability Test System          │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────┐      ┌──────────────┐       │
│  │ Coordinator  │◄────►│  Agent Alpha │       │
│  │  (Port 50051)│      │  (Port 50052)│       │
│  └──────────────┘      └──────────────┘       │
│         │                      │                │
│         │                      │                │
│  ┌──────────────┐      ┌──────────────┐       │
│  │  Agent Beta  │◄────►│ Agent Gamma  │       │
│  │  (Port 50053)│      │  (Port 50054)│       │
│  └──────────────┘      └──────────────┘       │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 环境要求

### 基本要求

- **操作系统**: Windows 10/11 或 Windows Server 2016+
- **PowerShell**: 5.1 或更高版本
- **内存**: 至少 4GB RAM
- **磁盘空间**: 至少 2GB 可用空间

### 可选组件（用于虚拟机测试）

- **VirtualBox**: 7.0.14 或更高版本
- **Vagrant**: 2.4.1 或更高版本
- **Docker Desktop**: 最新版本
- **Rust**: 1.75 或更高版本

### 安装依赖

如果需要安装可选组件，运行：

```powershell
# 以管理员身份运行
powershell -ExecutionPolicy Bypass -File "scripts\install_dependencies.ps1"
```

---

## 快速开始

### 1. 启动24小时稳定性测试

```powershell
# 基本启动（默认24小时）
powershell -ExecutionPolicy Bypass -File "scripts\24h_stability_test.ps1"

# 自定义测试时长（例如12小时）
powershell -ExecutionPolicy Bypass -File "scripts\24h_stability_test.ps1" -DurationHours 12

# 自定义日志目录
powershell -ExecutionPolicy Bypass -File "scripts\24h_stability_test.ps1" -LogDir "logs\my_test"
```

### 2. 监控测试进度

在另一个终端窗口中运行：

```powershell
# 基本监控（默认30秒刷新）
powershell -ExecutionPolicy Bypass -File "scripts\monitor_test.ps1"

# 自定义刷新间隔（例如10秒）
powershell -ExecutionPolicy Bypass -File "scripts\monitor_test.ps1" -RefreshInterval 10

# 监控特定日志目录
powershell -ExecutionPolicy Bypass -File "scripts\monitor_test.ps1" -LogDir "logs\my_test"
```

### 3. 生成测试报告

测试完成后运行：

```powershell
# 生成HTML报告
powershell -ExecutionPolicy Bypass -File "scripts\generate_test_report.ps1"

# 指定日志和输出目录
powershell -ExecutionPolicy Bypass -File "scripts\generate_test_report.ps1" -LogDir "logs\stability_test" -OutputDir "reports"
```

---

## 测试脚本说明

### 1. 24h_stability_test.ps1

**功能**: 执行24小时稳定性测试

**参数**:
- `DurationHours`: 测试时长（小时），默认24
- `LogDir`: 日志目录，默认"logs\stability_test"

**测试流程**:
1. 创建4个Agent（Coordinator + 3个普通Agent）
2. 执行随机操作循环：
   - 技能调用（30%概率）
   - 联邦学习上传（30%概率）
   - 合规检查（20%概率）
   - 混合操作（20%概率）
3. 每10次迭代输出统计信息
4. 测试结束后生成最终报告

**输出**:
- 实时控制台输出
- 详细日志文件
- 测试统计信息

### 2. monitor_test.ps1

**功能**: 实时监控测试进度

**参数**:
- `LogDir`: 日志目录，默认"logs\stability_test"
- `RefreshInterval`: 刷新间隔（秒），默认30

**监控内容**:
- 测试开始/结束时间
- 已运行/剩余时间
- 进度百分比
- 操作统计
- 成功率
- 操作频率（每小时）
- 系统状态

### 3. generate_test_report.ps1

**功能**: 生成HTML格式的测试报告

**参数**:
- `LogDir`: 日志目录，默认"logs\stability_test"
- `OutputDir`: 输出目录，默认"reports"

**报告内容**:
- 测试摘要（卡片式展示）
- 详细测试数据
- 延迟统计（平均值、中位数、P95、P99）
- 合规检查分布
- 错误日志
- 测试结论

---

## 监控测试

### 实时监控界面

监控脚本提供以下信息：

```
========================================
OpenClaw 24-Hour Stability Test Monitor
========================================

Time Information:
----------------------------------------
Start Time: 2026-03-31 22:48:58
Elapsed: 00:15:30
End Time: 2026-04-01 22:48:58
Remaining: 23:44:28
Progress: 1.08%
[=                                               ]

Last Activity: 2026-03-31 22:52:08
Idle Time: 00:00:00

Test Statistics:
----------------------------------------
Total Iterations: 25
Skill Calls: 12
FL Uploads: 8
Compliance Checks: 10
Errors: 0
Success Rate: 100%

Operations per Hour: 96.77

Status: RUNNING

Press Ctrl+C to stop monitoring
Next update in 30 seconds...
```

### 监控指标说明

- **Elapsed**: 已运行时间
- **Remaining**: 剩余时间
- **Progress**: 完成百分比
- **Operations per Hour**: 每小时操作数
- **Status**: 
  - RUNNING: 正常运行
  - IDLE: 超过5分钟无活动
  - COMPLETED: 测试完成

---

## 生成报告

### HTML报告示例

报告包含以下部分：

1. **测试摘要**: 关键指标卡片式展示
2. **测试详情**: 完整的测试数据表格
3. **延迟统计**: 
   - 技能调用延迟统计
   - 联邦学习上传延迟统计
4. **合规检查**: 按区域分布的统计
5. **错误日志**: 所有错误记录
6. **测试结论**: 基于成功率的评价

### 报告评价标准

- **Excellent** (≥99%): 系统表现出色
- **Good** (95-99%): 系统表现良好
- **Fair** (90-95%): 系统表现一般，存在一些问题
- **Poor** (<90%): 系统表现较差，存在多个问题

---

## 故障排查

### 常见问题

#### 1. 测试无法启动

**症状**: 运行脚本后立即退出

**解决方案**:
- 检查PowerShell执行策略：`Get-ExecutionPolicy`
- 如果受限，运行：`Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`
- 确保有足够的磁盘空间

#### 2. Agent启动失败

**症状**: 日志显示"Starting Agent"但没有成功消息

**解决方案**:
- 检查端口是否被占用：`netstat -ano | findstr "50051"`
- 如果端口被占用，停止占用进程或修改脚本中的端口号
- 检查防火墙设置

#### 3. 测试中途停止

**症状**: 测试运行一段时间后停止

**解决方案**:
- 检查系统资源使用情况
- 查看日志文件中的错误信息
- 确保系统不会进入休眠模式

#### 4. 监控脚本无响应

**症状**: 监控界面不更新

**解决方案**:
- 检查日志文件是否存在
- 确认测试脚本正在运行
- 尝试重启监控脚本

#### 5. 报告生成失败

**症状**: 生成报告时出现错误

**解决方案**:
- 确认测试已完成
- 检查日志文件是否完整
- 确保有写入输出目录的权限

### 日志文件位置

- **测试日志**: `logs\stability_test\stability_test_YYYYMMDD_HHMMSS.log`
- **报告文件**: `reports\stability_test_report_YYYYMMDD_HHMMSS.html`

### 获取帮助

如果遇到其他问题：

1. 查看详细的日志文件
2. 检查系统事件日志
3. 参考项目文档：[README.md](../README.md)
4. 查看技术文档：[TECHNICAL.md](../TECHNICAL.md)

---

## 测试最佳实践

### 1. 测试前准备

- 确保系统稳定运行
- 关闭不必要的应用程序
- 确保有足够的磁盘空间
- 配置电源管理，防止系统休眠

### 2. 测试期间

- 定期检查监控界面
- 关注错误日志
- 监控系统资源使用
- 保存测试配置和参数

### 3. 测试后

- 生成完整的测试报告
- 分析测试结果
- 记录任何异常情况
- 备份日志文件

---

## 附录

### A. 测试场景详情

#### 技能调用场景

- **summarize_pdf**: PDF文档摘要
- **analyze_image**: 图像分析
- **process_text**: 文本处理
- **extract_data**: 数据提取
- **classify_content**: 内容分类

#### 联邦学习任务

- **grasping_v1**: 抓取任务v1
- **navigation_v2**: 导航任务v2
- **perception_v3**: 感知任务v3
- **planning_v1**: 规划任务v1

#### 合规区域

- **CN**: 中国区域
- **US**: 美国区域
- **EU**: 欧洲区域
- **APAC**: 亚太区域

### B. 性能基准

基于测试结果，建议的性能指标：

- **技能调用延迟**: < 100ms (P95)
- **FL上传延迟**: < 200ms (P95)
- **成功率**: > 99%
- **操作频率**: > 50 ops/hour

### C. 相关文档

- [项目README](../README.md)
- [技术文档](../TECHNICAL.md)
- [部署指南](../DEPLOYMENT.md)
- [使用指南](../USAGE.md)
- [功能测试](../FUNCTIONAL_TEST.md)
- [沙盒测试](../SANDBOX_TEST.md)

---

**文档维护**: OpenClaw Team  
**最后更新**: 2026-03-31