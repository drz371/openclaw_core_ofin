# 无人机地面站集成方案

**版本**: v1.0
**日期**: 2026-05-15
**目标**: 将 OpenClaw Agent 框架整合到 UAV 地面站任务规划系统

---

## 一、集成架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    UAV 地面站控制系统                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ 任务规划   │  │ 飞行监控   │  │ 航迹管理                 │ │
│  │ Mission    │  │ Flight     │  │ Trajectory              │ │
│  │ Planning   │  │ Monitor    │  │ Management              │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                      │               │
│         └────────────────┼──────────────────────┘               │
│                          │                                      │
│                    ┌─────▼─────┐                                │
│                    │  REST API │                                │
│                    │  Gateway  │                                │
│                    └─────┬─────┘                                │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   gRPC/HTTP │
                    │   Adapter   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
   ┌─────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
   │  Planner  │    │  Monitor  │    │ Coordinator│
   │  Agent    │    │  Agent    │    │            │
   │ (任务规划) │    │ (监控分析) │    │ 协调器     │
   └───────────┘    └───────────┘    └────────────┘
```

---

## 二、UAV 专用 Agent 技能

### 2.1 任务规划 Agent (Planner Agent)

| 技能名 | 功能 | 输入 | 输出 |
|--------|------|------|------|
| `plan_mission` | 任务规划 | 目标点坐标、约束条件 | 航迹点序列 |
| `optimize_path` | 路径优化 | 起点、终点、障碍物 | 最优路径 |
| `分配任务` | 任务分配 | 多机信息、任务列表 | 分配方案 |
| `风应急` | 应急规划 | 风速、风向、当前位置 | 返航/迫降方案 |

### 2.2 监控分析 Agent (Monitor Agent)

| 技能名 | 功能 | 输入 | 输出 |
|--------|------|------|------|
| `analyze_telemetry` | 遥测分析 | 飞行数据JSON | 状态评估 |
| `detect_anomaly` | 异常检测 | 传感器数据 | 预警信息 |
| `predict_eta` | 到达预测 | 当前位置、目标点 | ETA预测 |
| `assess_battery` | 电量评估 | 当前电量、消耗速率 | 剩余时间 |

---

## 三、服务接口定义

### 3.1 HTTP REST API

```yaml
# UAV Ground Station Integration API

base_url: http://localhost:8080/api/v1

endpoints:
  # 任务规划
  POST /uav/mission/plan
    description: 创建任务规划
    body:
      {
        "uav_id": "UAV-001",
        "targets": [{"lat": 30.5, "lon": 114.3}, ...],
        "constraints": {"max_altitude": 100, "max_speed": 20}
      }
    response:
      {
        "mission_id": "M-2026-001",
        "waypoints": [...],
        "estimated_time": 3600
      }

  # 路径优化
  POST /uav/path/optimize
    description: 优化飞行路径
    body:
      {
        "start": {"lat": 30.5, "lon": 114.3, "alt": 50},
        "end": {"lat": 30.6, "lon": 114.4, "alt": 80},
        "obstacles": [{"type": "no_fly_zone", "circle": {...}}]
      }

  # 任务分配
  POST /uav/swarm/allocate
    description: 多机任务分配
    body:
      {
        "uavs": [{"id": "UAV-001", "battery": 80}, ...],
        "tasks": [{"id": "T1", "location": {...}}, ...]
      }

  # 遥测分析
  POST /uav/telemetry/analyze
    description: 分析飞行遥测数据
    body:
      {
        "uav_id": "UAV-001",
        "telemetry": {
          "lat": 30.5, "lon": 114.3, "alt": 50,
          "speed": 15, "heading": 90, "battery": 65
        }
      }
```

### 3.2 gRPC 接口

```protobuf
// uav_ground_station.proto

syntax = "proto3";
package uav;

service UAVMissionService {
  rpc PlanMission(PlanMissionRequest) returns (PlanMissionResponse);
  rpc OptimizePath(OptimizePathRequest) returns (OptimizePathResponse);
  rpc AllocateSwarmTasks(AllocateRequest) returns (AllocateResponse);
  rpc AnalyzeTelemetry(TelemetryRequest) returns (TelemetryResponse);
}

message Waypoint {
  double lat = 1;
  double lon = 2;
  double alt = 3;
  double speed = 4;
}

message MissionPlan {
  string mission_id = 1;
  repeated Waypoint waypoints = 2;
  int64 estimated_time_seconds = 3;
}
```

---

## 四、集成步骤

### 4.1 步骤一：启动 Agent 服务

```bash
# 1. 启动协调器
cargo run --bin clawfed -- server --addr "0.0.0.0:50051"

# 2. 启动 UAV 任务规划 Agent
cargo run --bin clawfed -- agent \
  --agent-id uav_planner \
  --addr "0.0.0.0:50101" \
  --server \
  --coordinator "http://127.0.0.1:50051"

# 3. 启动 UAV 监控 Agent
cargo run --bin clawfed -- agent \
  --agent-id uav_monitor \
  --addr "0.0.0.0:50102" \
  --server \
  --coordinator "http://127.0.0.1:50051"
```

### 4.2 步骤二：添加 UAV 技能

修改 `src/cli/mod.rs` 中的技能分配：

```rust
let skills = match agent_id.as_str() {
    "uav_planner" => vec![
        "plan_mission".to_string(),
        "optimize_path".to_string(),
        "allocate_tasks".to_string(),
        "emergency_planning".to_string(),
    ],
    "uav_monitor" => vec![
        "analyze_telemetry".to_string(),
        "detect_anomaly".to_string(),
        "predict_eta".to_string(),
        "assess_battery".to_string(),
    ],
    // ... 其他 Agent
};
```

### 4.3 步骤三：实现技能处理器

在 `src/net/server.rs` 中添加 UAV 技能处理：

```rust
async fn process_uav_skill(skill_name: &str, args_json: &str) -> String {
    match skill_name {
        "plan_mission" => {
            // 解析任务规划请求
            let req: MissionRequest = serde_json::from_str(args_json)
                .unwrap_or_default();
            // 调用路径规划算法
            plan_mission(&req)
        }
        "optimize_path" => {
            let req: PathRequest = serde_json::from_str(args_json)
                .unwrap_or_default();
            optimize_path(&req)
        }
        // ... 其他技能
    }
}
```

---

## 五、调用示例

### 5.1 通过 CLI 调用

```bash
# 任务规划
cargo run --bin clawfed -- call uav_planner plan_mission \
  --addr "http://127.0.0.1:50101" \
  --args '{
    "uav_id": "UAV-001",
    "targets": [{"lat": 30.5, "lon": 114.3}],
    "constraints": {"max_altitude": 100}
  }'

# 遥测分析
cargo run --bin clawfed -- call uav_monitor analyze_telemetry \
  --addr "http://127.0.0.1:50102" \
  --args '{
    "uav_id": "UAV-001",
    "telemetry": {"lat": 30.5, "lon": 114.3, "battery": 65}
  }'
```

### 5.2 通过 HTTP API 调用（需扩展）

```bash
# 任务规划
curl -X POST http://localhost:8080/api/v1/uav/mission/plan \
  -H "Content-Type: application/json" \
  -d '{
    "uav_id": "UAV-001",
    "targets": [{"lat": 30.5, "lon": 114.3}]
  }'
```

---

## 六、部署架构

```
                    ┌──────────────────┐
                    │  UAV Ground      │
                    │  Station Client  │
                    │  (Web/App)       │
                    └────────┬─────────┘
                             │ HTTP/gRPC
                             │
┌────────────────────────────┼────────────────────────────────────┐
│                     ┌──────▼──────┐                            │
│                     │   Nginx     │                            │
│                     │   Gateway   │                            │
│                     └──────┬──────┘                            │
│                            │                                   │
│         ┌──────────────────┼──────────────────┐                │
│         │                  │                  │                │
│   ┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼─────┐        │
│   │ Planner   │      │ Monitor   │      │ Coordinator│        │
│   │ Agent     │      │ Agent     │      │            │        │
│   │ :50101    │      │ :50102    │      │ :50051     │        │
│   └───────────┘      └───────────┘      └────────────┘        │
│                                                              │
│                        On-Premise / Cloud                     │
└──────────────────────────────────────────────────────────────┘
```

---

## 七、下一步

1. **确认具体需求**: 航迹规划算法、障碍物避障策略
2. **扩展技能**: 添加 `detect_obstacle`、`coordinate_swarm` 等
3. **集成LLM**: 利用 Hermes 的语言能力进行自然语言任务描述
4. **测试验证**: 在仿真环境中验证规划算法

---

**需要我继续实现具体的 UAV 技能处理器吗？**
