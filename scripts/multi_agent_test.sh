#!/bin/bash
# =====================================================
#   OpenClaw 多 Agent 协作测试脚本
#   功能：启动多个 Agent 并测试它们之间的协作
#   适用系统：Linux / macOS
# =====================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  OpenClaw 多 Agent 协作测试${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 检查可执行文件
if [ ! -f "./target/release/clawfed" ]; then
    echo -e "${YELLOW}  未找到可执行文件，正在编译...${NC}"
    cargo build --release
fi

CLAWFED="./target/release/clawfed"

# 清理函数
cleanup() {
    echo -e "${YELLOW}停止所有服务...${NC}"
    pkill -f "clawfed server" 2>/dev/null || true
    pkill -f "clawfed agent" 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}清理完成${NC}"
}

trap cleanup EXIT

# 清理旧进程
cleanup

# 创建测试数据
echo -e "${BLUE}创建测试数据...${NC}"
echo -ne '\x4C\x6F\x52\x41\x00\x01' > test_delta.lora

# 启动协调器
echo ""
echo -e "${YELLOW}启动协调器（端口 50051）...${NC}"
$CLAWFED server --addr "0.0.0.0:50051" --agent-id coordinator > /dev/null 2>&1 &
COORD_PID=$!
echo -e "${GREEN}✓ 协调器已启动 (PID: $COORD_PID)${NC}"

# 启动多个 Agent
echo ""
echo -e "${YELLOW}启动 Agent 集群...${NC}"
echo ""

echo -e "${BLUE}  [1/3] 视觉 Agent (端口 50052)${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50052" > /dev/null 2>&1 &
AGENT1_PID=$!
echo -e "${GREEN}  ✓ 视觉 Agent 已启动 (PID: $AGENT1_PID)${NC}"

echo -e "${BLUE}  [2/3] NLP Agent (端口 50053)${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50053" > /dev/null 2>&1 &
AGENT2_PID=$!
echo -e "${GREEN}  ✓ NLP Agent 已启动 (PID: $AGENT2_PID)${NC}"

echo -e "${BLUE}  [3/3] 机器人 Agent (端口 50054)${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50054" > /dev/null 2>&1 &
AGENT3_PID=$!
echo -e "${GREEN}  ✓ 机器人 Agent 已启动 (PID: $AGENT3_PID)${NC}"

# 等待服务就绪
sleep 2

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  所有 Agent 已就绪！开始测试...${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# 测试函数
test_skill() {
    local agent_id=$1
    local skill=$2
    local args=$3
    local port=$4

    echo -e "${BLUE}测试: agent_0${port} -> $skill${NC}"
    if $CLAWFED call "$agent_id" "$skill" --addr "http://127.0.0.1:${port}" --args "$args" 2>&1 | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ 成功${NC}"
    else
        echo -e "${RED}  ✗ 失败${NC}"
    fi
    echo ""
}

# ===== 测试开始 =====

echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  1. 技能调用测试${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""

test_skill "agent_01" "detect_objects" '{"url": "https://example.com/image.jpg"}' "50052"
test_skill "agent_01" "summarize_pdf" '{"file": "document.pdf"}' "50052"
test_skill "agent_02" "detect_objects" '{"url": "https://example.com/photo.jpg"}' "50053"
test_skill "agent_03" "detect_objects" '{"url": "https://example.com/scene.jpg"}' "50054"

echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  2. 合规拦截测试${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}测试: 合规拦截 (face_detect 应被拦截)${NC}"
RESULT=$($CLAWFED call agent_01 face_detect --addr "http://127.0.0.1:50052" --args '{}' 2>&1 || true)
if echo "$RESULT" | grep -q "Compliance check failed"; then
    echo -e "${GREEN}  ✓ 合规拦截正常工作${NC}"
else
    echo -e "${RED}  ✗ 合规拦截异常${NC}"
fi
echo ""

echo -e "${BLUE}测试: 合规拦截 (raw_data 应被拦截)${NC}"
RESULT=$($CLAWFED call agent_01 raw_data --addr "http://127.0.0.1:50052" --args '{}' 2>&1 || true)
if echo "$RESULT" | grep -q "Compliance check failed"; then
    echo -e "${GREEN}  ✓ 合规拦截正常工作${NC}"
else
    echo -e "${RED}  ✗ 合规拦截异常${NC}"
fi
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  3. 联邦学习测试${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}测试: 上传模型增量 (grasping_v1)${NC}"
if $CLAWFED fl upload-delta --task grasping_v1 --file test_delta.lora --coordinator "http://127.0.0.1:50051" 2>&1 | grep -q "Called skill"; then
    echo -e "${GREEN}  ✓ 联邦学习上传成功${NC}"
else
    echo -e "${RED}  ✗ 联邦学习上传失败${NC}"
fi
echo ""

echo -e "${BLUE}测试: 合规拦截 (biometric_task 应被拦截)${NC}"
RESULT=$($CLAWFED fl upload-delta --task biometric_task --file test_delta.lora --coordinator "http://127.0.0.1:50051" 2>&1 || true)
if echo "$RESULT" | grep -q "Compliance check failed"; then
    echo -e "${GREEN}  ✓ 合规拦截正常工作${NC}"
else
    echo -e "${RED}  ✗ 合规拦截异常${NC}"
fi
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  4. 服务稳定性检查${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""

CHECK_ALL=true
for pid in $COORD_PID $AGENT1_PID $AGENT2_PID $AGENT3_PID; do
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}  ✓ 进程 $pid 运行正常${NC}"
    else
        echo -e "${RED}  ✗ 进程 $pid 已退出${NC}"
        CHECK_ALL=false
    fi
done
echo ""

# 最终结果
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  测试完成！${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

if $CHECK_ALL; then
    echo -e "${GREEN}✓ 所有 Agent 运行正常${NC}"
else
    echo -e "${RED}✗ 部分 Agent 异常退出${NC}"
fi

echo ""
echo -e "${YELLOW}  按 Ctrl+C 停止所有服务${NC}"
echo ""

# 保持运行直到用户中断
wait
