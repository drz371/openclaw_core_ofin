#!/bin/bash
# =====================================================
#   OpenClaw × Hermes 多 Agent 协作测试脚本
#   默认启动 OpenClaw 和 Hermes 两个 Agent 进行互联测试
#   适用系统：Linux / macOS
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     OpenClaw × Hermes 多 Agent 协作测试           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

CLAWFED="./target/release/clawfed"

if [ ! -f "$CLAWFED" ]; then
    echo -e "${YELLOW}  未找到可执行文件，正在编译...${NC}"
    cargo build --release
fi

cleanup() {
    echo ""
    echo -e "${YELLOW}停止所有服务...${NC}"
    pkill -f "clawfed server" 2>/dev/null || true
    pkill -f "clawfed agent" 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}清理完成${NC}"
}

trap cleanup EXIT
cleanup

echo -e "${BLUE}创建测试数据...${NC}"
echo -ne '\x4C\x6F\x52\x41\x00\x01' > test_delta.lora

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  启动 OpenClaw Agent (agent_01)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}  [OpenClaw] 启动服务（端口 50052）...${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50052" --agent-id "agent_01" > /dev/null 2>&1 &
OPENCLAW_PID=$!
echo -e "${GREEN}  ✓ OpenClaw 已启动 (PID: $OPENCLAW_PID)${NC}"
echo -e "${GREEN}  ✓ Agent ID: agent_01${NC}"
echo -e "${GREEN}  ✓ 技能: detect_objects, summarize_pdf, process_data${NC}"

echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}  启动 Hermes Agent (agent_02)${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}  [Hermes] 启动服务（端口 50053）...${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50053" --agent-id "agent_02" > /dev/null 2>&1 &
HERMES_PID=$!
echo -e "${GREEN}  ✓ Hermes 已启动 (PID: $HERMES_PID)${NC}"
echo -e "${GREEN}  ✓ Agent ID: agent_02${NC}"
echo -e "${GREEN}  ✓ 技能: analyze_context, generate_response, translate_text${NC}"

echo ""
echo -e "${YELLOW}启动协调器（端口 50051）...${NC}"
$CLAWFED server --addr "0.0.0.0:50051" --agent-id coordinator > /dev/null 2>&1 &
COORD_PID=$!
echo -e "${GREEN}✓ 协调器已启动 (PID: $COORD_PID)${NC}"

sleep 2

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   OpenClaw × Hermes 已就绪，开始互联测试！          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

test_skill() {
    local agent_id=$1
    local skill=$2
    local args=$3
    local port=$4
    local agent_name=$5

    echo -e "${BLUE}测试: ${agent_name} -> $skill${NC}"
    if $CLAWFED call "$agent_id" "$skill" --addr "http://127.0.0.1:${port}" --args "$args" 2>&1 | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ 成功${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 失败${NC}"
        return 1
    fi
}

cross_agent_test() {
    local source=$1
    local target=$2
    local target_port=$3
    local skill=$4
    local args=$5

    echo -e "${BLUE}跨 Agent 调用: ${source} -> ${target} ($skill)${NC}"
    if $CLAWFED call "$target" "$skill" --addr "http://127.0.0.1:${target_port}" --args "$args" 2>&1 | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ 跨 Agent 通信成功${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 跨 Agent 通信失败${NC}"
        return 1
    fi
}

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  1. OpenClaw Agent (agent_01) 技能测试${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

test_skill "agent_01" "detect_objects" '{"url": "https://example.com/image.jpg"}' "50052" "OpenClaw"
test_skill "agent_01" "summarize_pdf" '{"file": "document.pdf"}' "50052" "OpenClaw"
test_skill "agent_01" "process_data" '{"dataset": "train.csv"}' "50052" "OpenClaw"

echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}  2. Hermes Agent (agent_02) 技能测试${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

test_skill "agent_02" "analyze_context" '{"text": "Hello world"}' "50053" "Hermes"
test_skill "agent_02" "generate_response" '{"prompt": "What is AI?"}' "50053" "Hermes"
test_skill "agent_02" "translate_text" '{"text": "Hello", "to": "zh"}' "50053" "Hermes"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  3. OpenClaw × Hermes 跨 Agent 协作测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}  OpenClaw 调用 Hermes 的翻译技能${NC}"
cross_agent_test "OpenClaw" "agent_02" "50053" "translate_text" '{"text": "Hello OpenClaw", "to": "zh"}'

echo ""
echo -e "${PURPLE}  Hermes 调用 OpenClaw 的图像识别技能${NC}"
cross_agent_test "Hermes" "agent_01" "50052" "detect_objects" '{"url": "https://example.com/photo.jpg"}'

echo ""
echo -e "${CYAN}  OpenClaw 调用 Hermes 的上下文分析技能${NC}"
cross_agent_test "OpenClaw" "agent_02" "50053" "analyze_context" '{"text": "联邦学习协作"}'

echo ""
echo -e "${PURPLE}  Hermes 调用 OpenClaw 的数据处理技能${NC}"
cross_agent_test "Hermes" "agent_01" "50052" "process_data" '{"dataset": "collaboration_data.csv"}'

echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  4. 合规拦截测试${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BLUE}测试: OpenClaw 合规拦截 (face_detect 应被拦截)${NC}"
RESULT=$($CLAWFED call agent_01 face_detect --addr "http://127.0.0.1:50052" --args '{}' 2>&1 || true)
if echo "$RESULT" | grep -q "Compliance check failed"; then
    echo -e "${GREEN}  ✓ OpenClaw 合规拦截正常${NC}"
else
    echo -e "${RED}  ✗ OpenClaw 合规拦截异常${NC}"
fi

echo ""
echo -e "${BLUE}测试: Hermes 合规拦截 (face_detect 应被拦截)${NC}"
RESULT=$($CLAWFED call agent_02 face_detect --addr "http://127.0.0.1:50053" --args '{}' 2>&1 || true)
if echo "$RESULT" | grep -q "Compliance check failed"; then
    echo -e "${GREEN}  ✓ Hermes 合规拦截正常${NC}"
else
    echo -e "${RED}  ✗ Hermes 合规拦截异常${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  5. 联邦学习测试${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BLUE}测试: OpenClaw 上传模型增量 (grasping_v1)${NC}"
if $CLAWFED fl upload-delta --task grasping_v1 --file test_delta.lora --coordinator "http://127.0.0.1:50051" 2>&1 | grep -q "Called skill"; then
    echo -e "${GREEN}  ✓ OpenClaw 联邦学习上传成功${NC}"
else
    echo -e "${RED}  ✗ OpenClaw 联邦学习上传失败${NC}"
fi

echo ""
echo -e "${BLUE}测试: Hermes 上传模型增量 (nlp_v1)${NC}"
if $CLAWFED fl upload-delta --task nlp_v1 --file test_delta.lora --coordinator "http://127.0.0.1:50051" 2>&1 | grep -q "Called skill"; then
    echo -e "${GREEN}  ✓ Hermes 联邦学习上传成功${NC}"
else
    echo -e "${RED}  ✗ Hermes 联邦学习上传失败${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  6. 服务稳定性检查${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

CHECK_ALL=true

for pid_info in "OpenClaw:$OPENCLAW_PID" "Hermes:$HERMES_PID" "Coordinator:$COORD_PID"; do
    name="${pid_info%%:*}"
    pid="${pid_info##*:}"
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}  ✓ ${name} (PID: $pid) 运行正常${NC}"
    else
        echo -e "${RED}  ✗ ${name} (PID: $pid) 已退出${NC}"
        CHECK_ALL=false
    fi
done

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         OpenClaw × Hermes 协作测试完成！          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

if $CHECK_ALL; then
    echo -e "${GREEN}✓ 所有 Agent 运行正常${NC}"
else
    echo -e "${RED}✗ 部分 Agent 异常退出${NC}"
fi

echo ""
echo -e "${CYAN}  OpenClaw: http://127.0.0.1:50052 (agent_01)${NC}"
echo -e "${PURPLE}  Hermes:   http://127.0.0.1:50053 (agent_02)${NC}"
echo -e "${YELLOW}  Coordinator: http://127.0.0.1:50051${NC}"
echo ""
echo -e "${YELLOW}  按 Ctrl+C 停止所有服务${NC}"
echo ""

wait
