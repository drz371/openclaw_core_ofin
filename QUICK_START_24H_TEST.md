# OpenClaw 24小时稳定性测试 - 快速启动指南

## 🚀 快速启动

### 1. 启动测试（24小时）
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\24h_stability_test.ps1"
```

### 2. 监控测试（新终端窗口）
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\monitor_test.ps1"
```

### 3. 生成报告（测试完成后）
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\generate_test_report.ps1"
```

---

## 📊 测试状态

**当前状态**: ✅ 正在运行  
**开始时间**: 2026-03-31 22:48:58  
**结束时间**: 2026-04-01 22:48:58  
**测试时长**: 24小时  
**已运行时间**: 约5分钟  
**剩余时间**: 约23小时55分钟  

---

## 📁 文件位置

- **测试脚本**: `scripts/24h_stability_test.ps1`
- **监控脚本**: `scripts/monitor_test.ps1`
- **报告脚本**: `scripts/generate_test_report.ps1`
- **日志文件**: `logs/stability_test/stability_test_20260331_224858.log`
- **详细文档**: `24H_STABILITY_TEST_GUIDE.md`

---

## 🔧 自定义选项

### 修改测试时长
```powershell
# 测试12小时
powershell -ExecutionPolicy Bypass -File "scripts\24h_stability_test.ps1" -DurationHours 12

# 测试6小时
powershell -ExecutionPolicy Bypass -File "scripts\24h_stability_test.ps1" -DurationHours 6
```

### 修改监控刷新间隔
```powershell
# 每10秒刷新
powershell -ExecutionPolicy Bypass -File "scripts\monitor_test.ps1" -RefreshInterval 10

# 每60秒刷新
powershell -ExecutionPolicy Bypass -File "scripts\monitor_test.ps1" -RefreshInterval 60
```

---

## 📈 测试内容

测试包含以下操作：

1. **技能调用** (30%概率)
   - summarize_pdf
   - analyze_image
   - process_text
   - extract_data
   - classify_content

2. **联邦学习上传** (30%概率)
   - grasping_v1
   - navigation_v2
   - perception_v3
   - planning_v1

3. **合规检查** (20%概率)
   - CN, US, EU, APAC区域

4. **混合操作** (20%概率)
   - 组合多种操作

---

## 🎯 测试架构

```
Coordinator (Port 50051)
    │
    ├── Agent Alpha (Port 50052)
    ├── Agent Beta (Port 50053)
    └── Agent Gamma (Port 50054)
```

---

## ⚠️ 注意事项

1. **不要关闭测试终端** - 测试将在后台运行24小时
2. **使用监控脚本** - 在新终端窗口中运行监控脚本查看进度
3. **系统休眠** - 确保系统不会进入休眠模式
4. **磁盘空间** - 确保有足够的磁盘空间存储日志

---

## 📞 获取帮助

- **详细文档**: [24H_STABILITY_TEST_GUIDE.md](24H_STABILITY_TEST_GUIDE.md)
- **项目文档**: [README.md](README.md)
- **技术文档**: [TECHNICAL.md](TECHNICAL.md)

---

## 🎉 测试完成后

1. 测试将自动停止所有Agent
2. 运行报告生成脚本
3. 在浏览器中打开生成的HTML报告
4. 分析测试结果和统计数据

---

**测试正在运行中...** ✅