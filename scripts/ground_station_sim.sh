#!/usr/bin/env bash

echo "=============================================="
echo "    🚁 UAV地面站模拟器 v1.0"
echo "    OpenClaw × Hermes × UAV Planner"
echo "=============================================="
echo ""

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}[1/5] 启动 LLM Mock Server...${NC}"
cargo run --quiet --example llm_mock_server &>/tmp/llm_server.log &
LLM_PID=$!
sleep 2
echo -e "${GREEN}✓ LLM Server 已启动${NC}"

echo -e "${BLUE}[2/5] 启动 Coordinator...${NC}"
cargo run --quiet --bin clawfed -- server --addr '127.0.0.1:50051' --agent-id coordinator &>/tmp/coord.log &
COORD_PID=$!
sleep 2
echo -e "${GREEN}✓ Coordinator 已启动${NC}"

echo -e "${BLUE}[3/5] 启动 OpenClaw Agent...${NC}"
cargo run --quiet --bin clawfed -- agent --agent-id openclaw --addr '127.0.0.1:50052' --server --coordinator 'http://127.0.0.1:50051' &>/tmp/openclaw.log &
OPENCLAW_PID=$!
sleep 2
echo -e "${GREEN}✓ OpenClaw 已启动${NC}"

echo -e "${BLUE}[4/5] 启动 Hermes Agent...${NC}"
cargo run --quiet --bin clawfed -- agent --agent-id hermes --addr '127.0.0.1:50053' --server --coordinator 'http://127.0.0.1:50051' &>/tmp/hermes.log &
HERMES_PID=$!
sleep 2
echo -e "${GREEN}✓ Hermes 已启动${NC}"

echo -e "${BLUE}[5/5] 启动 UAV Planner Agent...${NC}"
cargo run --quiet --bin clawfed -- agent --agent-id uav_planner --addr '127.0.0.1:50101' --server --coordinator 'http://127.0.0.1:50051' &>/tmp/uav_planner.log &
UAV_PID=$!
sleep 3
echo -e "${GREEN}✓ UAV Planner 已启动${NC}"

echo ""
echo "=============================================="
echo "           🎯 地面站模拟演示"
echo "=============================================="
echo ""

echo -e "${YELLOW}[演示1] 自动航线规划 - 光伏电站巡检${NC}"
echo "正在生成巡检航线..."
RESULT=$(cargo run --quiet --bin clawfed -- call uav_planner auto_patrol \
  --addr 'http://127.0.0.1:50101' \
  --args '{
    "start_lat": 30.5, "start_lon": 114.3, "start_alt": 10,
    "zone_name": "SolarFarm-A",
    "zone_center_lat": 30.5, "zone_center_lon": 114.3,
    "zone_width": 500, "zone_height": 400,
    "flight_altitude": 50, "overlap_percent": 20
  }' 2>&1)

echo "输出结果:"
echo "$RESULT" | grep -E "(path_id|total_distance|estimated_time|battery_required|coverage)" | head -5
echo ""

echo -e "${YELLOW}[演示2] 工业巡检规划 - 电力线路检查${NC}"
echo "正在生成巡检计划..."
RESULT=$(cargo run --quiet --bin clawfed -- call uav_planner industrial_inspection \
  --addr 'http://127.0.0.1:50101' \
  --args '{
    "uav_id": "UAV-001",
    "zone_name": "PowerLine-Section-1",
    "zone_center_lat": 31.0, "zone_center_lon": 115.0,
    "zone_width": 2000, "zone_height": 100,
    "flight_altitude": 80,
    "facility_type": "power_line"
  }' 2>&1)

echo "输出结果:"
echo "$RESULT" | grep -E "(plan_id|facility_type|estimated_duration|checklist)" | head -5
echo ""

echo -e "${YELLOW}[演示3] 遥测数据分析${NC}"
echo "正在分析无人机状态..."
RESULT=$(cargo run --quiet --bin clawfed -- call uav_planner analyze_telemetry \
  --addr 'http://127.0.0.1:50101' \
  --args '{
    "uav_id": "UAV-001",
    "lat": 30.5, "lon": 114.3, "alt": 50,
    "speed": 8.5, "heading": 90,
    "battery": 68,
    "timestamp": 1747200000
  }' 2>&1)

echo "输出结果:"
echo "$RESULT" | grep -E "(battery_status|speed_status|health_score|warnings|recommendations)" | head -5
echo ""

echo -e "${YELLOW}[演示4] 调用Hermes进行数据分析${NC}"
echo "正在分析任务数据..."
RESULT=$(cargo run --quiet --bin clawfed -- call hermes analyze_context \
  --addr 'http://127.0.0.1:50053' \
  --args '{"data": "UAV任务完成分析", "query": "分析今日巡检任务完成情况"}' 2>&1)

echo "输出结果:"
echo "$RESULT" | grep -E "(response|status)" | head -2
echo ""

echo "=============================================="
echo "              📊 系统状态汇总"
echo "=============================================="
echo ""

echo -e "${GREEN}运行中的服务:${NC}"
echo "  ✅ Coordinator    : 127.0.0.1:50051"
echo "  ✅ OpenClaw       : 127.0.0.1:50052"
echo "  ✅ Hermes         : 127.0.0.1:50053"
echo "  ✅ UAV Planner    : 127.0.0.1:50101"
echo "  ✅ LLM Mock       : 127.0.0.1:8080"
echo ""

echo -e "${YELLOW}命令汇总:${NC}"
echo "  # 启动地面站"
echo "  bash scripts/ground_station_sim.sh"
echo ""
echo "  # 手动调用技能"
echo "  cargo run --bin clawfed -- call uav_planner auto_patrol ..."
echo ""
echo "  # 停止所有服务"
echo "  kill $LLM_PID $COORD_PID $OPENCLAW_PID $HERMES_PID $UAV_PID"
echo ""

read -p "按 Enter 停止所有服务..."

echo -e "${RED}正在停止服务...${NC}"
kill $LLM_PID $COORD_PID $OPENCLAW_PID $HERMES_PID $UAV_PID 2>/dev/null
echo -e "${GREEN}✓ 所有服务已停止${NC}"
echo ""
