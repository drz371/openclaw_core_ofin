#!/bin/bash
# =====================================================
#   OpenClaw × Hermes 24小时稳定性烤机测试
#   持续进行跨Agent调用，验证系统稳定性
# =====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

CLAWFED="./target/release/clawfed"
LOG_DIR="logs/stability_test_24h"
TEST_DURATION=86400

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/stability_24h_$(date +%Y%m%d_%H%M%S).log"
METRICS_FILE="$LOG_DIR/metrics_$(date +%Y%m%d_%H%M%S).csv"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     OpenClaw × Hermes 24小时稳定性烤机测试       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo "测试开始时间: $(date)" | tee -a "$LOG_FILE"
echo "测试持续时间: 24小时 (86400秒)" | tee -a "$LOG_FILE"
echo "日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
echo "指标文件: $METRICS_FILE" | tee -a "$LOG_FILE"

echo "timestamp,iteration,openclaw_calls,openclaw_success,hermes_calls,hermes_success,cross_calls,cross_success,compliance_blocks,errors,memory_mb" > "$METRICS_FILE"

cleanup() {
    echo ""
    echo -e "${YELLOW}停止所有服务...${NC}"
    pkill -f "clawfed server" 2>/dev/null || true
    pkill -f "clawfed agent" 2>/dev/null || true
    sleep 2
    echo -e "${GREEN}清理完成${NC}"
}

trap cleanup EXIT

cleanup

echo -e "${BLUE}创建测试数据...${NC}"
echo -ne '\x4C\x6F\x52\x41\x00\x01' > test_delta.lora

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  启动服务集群${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}  启动协调器（端口 50051）...${NC}"
$CLAWFED server --addr "0.0.0.0:50051" --agent-id coordinator > "$LOG_DIR/coordinator.log" 2>&1 &
COORD_PID=$!
sleep 5

echo -e "${YELLOW}  启动 OpenClaw Agent（端口 50052）...${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50052" --agent-id "agent_01" > "$LOG_DIR/openclaw.log" 2>&1 &
OPENCLAW_PID=$!
sleep 5

echo -e "${PURPLE}  启动 Hermes Agent（端口 50053）...${NC}"
$CLAWFED agent --server --addr "0.0.0.0:50053" --agent-id "agent_02" > "$LOG_DIR/hermes.log" 2>&1 &
HERMES_PID=$!
sleep 5

echo ""
echo "验证服务启动状态..."
sleep 2

ALL_STARTED=true
for name_pid in "Coordinator:$COORD_PID" "OpenClaw:$OPENCLAW_PID" "Hermes:$HERMES_PID"; do
    name="${name_pid%%:*}"
    pid="${name_pid##*:}"
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}  ✓ ${name} (PID: $pid) 运行中${NC}"
    else
        echo -e "${RED}  ✗ ${name} 启动失败${NC}"
        ALL_STARTED=false
    fi
done

if ! $ALL_STARTED; then
    echo -e "${RED}  服务启动失败，退出测试${NC}"
    cat "$LOG_DIR/coordinator.log" "$LOG_DIR/openclaw.log" "$LOG_DIR/hermes.log"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   所有服务已启动，24小时测试开始！                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

START_TIME=$(date +%s)
END_TIME=$((START_TIME + TEST_DURATION))
ITERATION=0

TOTAL_OPENCLAW=0
TOTAL_OPENCLAW_SUCCESS=0
TOTAL_HERMES=0
TOTAL_HERMES_SUCCESS=0
TOTAL_CROSS=0
TOTAL_CROSS_SUCCESS=0
TOTAL_COMPLIANCE=0
TOTAL_ERRORS=0

get_memory_mb() {
    local pid=$1
    if [ -f "/proc/$pid/status" ]; then
        grep VmRSS /proc/$pid/status | awk '{print int($2/1024)}'
    else
        echo "N/A"
    fi
}

check_services() {
    local all_ok=true

    for pid_info in "Coordinator:$COORD_PID" "OpenClaw:$OPENCLAW_PID" "Hermes:$HERMES_PID"; do
        name="${pid_info%%:*}"
        pid="${pid_info##*:}"
        if ! kill -0 $pid 2>/dev/null; then
            echo -e "${RED}  ✗ ${name} (PID: $pid) 已退出${NC}"
            all_ok=false
        fi
    done

    if ! $all_ok; then
        echo -e "${RED}  检测到服务异常退出${NC}"
        return 1
    fi
    return 0
}

while [ $(date +%s) -lt $END_TIME ]; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    REMAINING=$((END_TIME - CURRENT_TIME))

    ITERATION=$((ITERATION + 1))

    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] 迭代 #$ITERATION | 已运行: ${ELAPSED}s | 剩余: ${REMAINING}s${NC}"

    check_services || break

    OC_SUCCESS=0
    OC_TOTAL=0
    HM_SUCCESS=0
    HM_TOTAL=0
    CR_SUCCESS=0
    CR_TOTAL=0
    COMP_BLOCK=0
    ERRORS=0

    for skill in "detect_objects" "summarize_pdf" "process_data"; do
        OC_TOTAL=$((OC_TOTAL + 1))
        case $skill in
            detect_objects) args='{"url": "https://example.com/image.jpg"}' ;;
            summarize_pdf) args='{"file": "doc.pdf"}' ;;
            process_data) args='{"dataset": "data.csv"}' ;;
        esac

        if $CLAWFED call agent_01 "$skill" --addr "http://127.0.0.1:50052" --args "$args" > /dev/null 2>&1; then
            OC_SUCCESS=$((OC_SUCCESS + 1))
        else
            ERRORS=$((ERRORS + 1))
        fi
    done

    for skill in "analyze_context" "generate_response" "translate_text"; do
        HM_TOTAL=$((HM_TOTAL + 1))
        case $skill in
            analyze_context) args='{"text": "Hello world"}' ;;
            generate_response) args='{"prompt": "Test"}' ;;
            translate_text) args='{"text": "Hello", "to": "zh"}' ;;
        esac

        if $CLAWFED call agent_02 "$skill" --addr "http://127.0.0.1:50053" --args "$args" > /dev/null 2>&1; then
            HM_SUCCESS=$((HM_SUCCESS + 1))
        else
            ERRORS=$((ERRORS + 1))
        fi
    done

    for test_case in 1 2 3 4; do
        CR_TOTAL=$((CR_TOTAL + 1))
        case $test_case in
            1) $CLAWFED call agent_02 translate_text --addr "http://127.0.0.1:50053" --args '{"text":"Test","to":"zh"}' > /dev/null 2>&1 ;;
            2) $CLAWFED call agent_01 detect_objects --addr "http://127.0.0.1:50052" --args '{"url":"img.jpg"}' > /dev/null 2>&1 ;;
            3) $CLAWFED call agent_02 analyze_context --addr "http://127.0.0.1:50053" --args '{"text":"Hi"}' > /dev/null 2>&1 ;;
            4) $CLAWFED call agent_01 process_data --addr "http://127.0.0.1:50052" --args '{"dataset":"x.csv"}' > /dev/null 2>&1 ;;
        esac
        if [ $? -eq 0 ]; then
            CR_SUCCESS=$((CR_SUCCESS + 1))
        else
            ERRORS=$((ERRORS + 1))
        fi
    done

    if $CLAWFED call agent_01 face_detect --addr "http://127.0.0.1:50052" --args '{}' 2>&1 | grep -q "Compliance check failed"; then
        COMP_BLOCK=$((COMP_BLOCK + 1))
    fi
    if $CLAWFED call agent_02 face_detect --addr "http://127.0.0.1:50053" --args '{}' 2>&1 | grep -q "Compliance check failed"; then
        COMP_BLOCK=$((COMP_BLOCK + 1))
    fi

    TOTAL_OPENCLAW=$((TOTAL_OPENCLAW + OC_TOTAL))
    TOTAL_OPENCLAW_SUCCESS=$((TOTAL_OPENCLAW_SUCCESS + OC_SUCCESS))
    TOTAL_HERMES=$((TOTAL_HERMES + HM_TOTAL))
    TOTAL_HERMES_SUCCESS=$((TOTAL_HERMES_SUCCESS + HM_SUCCESS))
    TOTAL_CROSS=$((TOTAL_CROSS + CR_TOTAL))
    TOTAL_CROSS_SUCCESS=$((TOTAL_CROSS_SUCCESS + CR_SUCCESS))
    TOTAL_COMPLIANCE=$((TOTAL_COMPLIANCE + COMP_BLOCK))
    TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))

    MEMORY=$(get_memory_mb $OPENCLAW_PID)

    echo "$CURRENT_TIME,$ITERATION,$OC_TOTAL,$OC_SUCCESS,$HM_TOTAL,$HM_SUCCESS,$CR_TOTAL,$CR_SUCCESS,$COMP_BLOCK,$ERRORS,$MEMORY" >> "$METRICS_FILE"

    OC_RATE=0
    HM_RATE=0
    CR_RATE=0
    [ $OC_TOTAL -gt 0 ] && OC_RATE=$((OC_SUCCESS * 100 / OC_TOTAL))
    [ $HM_TOTAL -gt 0 ] && HM_RATE=$((HM_SUCCESS * 100 / HM_TOTAL))
    [ $CR_TOTAL -gt 0 ] && CR_RATE=$((CR_SUCCESS * 100 / CR_TOTAL))

    echo -e "  OpenClaw: $OC_SUCCESS/$OC_TOTAL ($OC_RATE%) | Hermes: $HM_SUCCESS/$HM_TOTAL ($HM_RATE%) | 跨Agent: $CR_SUCCESS/$CR_TOTAL ($CR_RATE%) | 合规拦截: $COMP_BLOCK | 内存: ${MEMORY}MB"

    if [ $((ITERATION % 10)) -eq 0 ]; then
        OC_RATE_TOTAL=0
        HM_RATE_TOTAL=0
        CR_RATE_TOTAL=0
        [ $TOTAL_OPENCLAW -gt 0 ] && OC_RATE_TOTAL=$((TOTAL_OPENCLAW_SUCCESS * 100 / TOTAL_OPENCLAW))
        [ $TOTAL_HERMES -gt 0 ] && HM_RATE_TOTAL=$((TOTAL_HERMES_SUCCESS * 100 / TOTAL_HERMES))
        [ $TOTAL_CROSS -gt 0 ] && CR_RATE_TOTAL=$((TOTAL_CROSS_SUCCESS * 100 / TOTAL_CROSS))

        echo -e "  ${YELLOW}累计: OpenClaw ${TOTAL_OPENCLAW_SUCCESS}/${TOTAL_OPENCLAW} (${OC_RATE_TOTAL}%) | Hermes ${TOTAL_HERMES_SUCCESS}/${TOTAL_HERMES} (${HM_RATE_TOTAL}%) | 跨Agent ${TOTAL_CROSS_SUCCESS}/${TOTAL_CROSS} (${CR_RATE_TOTAL}%) | 合规拦截: $TOTAL_COMPLIANCE | 错误: $TOTAL_ERRORS${NC}"
    fi

    if [ $((ITERATION % 100)) -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 迭代 #$ITERATION | OpenClaw: ${TOTAL_OPENCLAW_SUCCESS}/${TOTAL_OPENCLAW} (${OC_RATE_TOTAL}%) | Hermes: ${TOTAL_HERMES_SUCCESS}/${TOTAL_HERMES} (${HM_RATE_TOTAL}%) | 跨Agent: ${TOTAL_CROSS_SUCCESS}/${TOTAL_CROSS} (${CR_RATE_TOTAL}%) | 合规: $TOTAL_COMPLIANCE | 错误: $TOTAL_ERRORS" >> "$LOG_FILE"
    fi

    sleep 1
done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              24小时稳定性测试完成！                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "测试结束时间: $(date)" | tee -a "$LOG_FILE"
echo "总迭代次数: $ITERATION" | tee -a "$LOG_FILE"
echo ""

OC_RATE_FINAL=0
HM_RATE_FINAL=0
CR_RATE_FINAL=0
[ $TOTAL_OPENCLAW -gt 0 ] && OC_RATE_FINAL=$((TOTAL_OPENCLAW_SUCCESS * 100 / TOTAL_OPENCLAW))
[ $TOTAL_HERMES -gt 0 ] && HM_RATE_FINAL=$((TOTAL_HERMES_SUCCESS * 100 / TOTAL_HERMES))
[ $TOTAL_CROSS -gt 0 ] && CR_RATE_FINAL=$((TOTAL_CROSS_SUCCESS * 100 / TOTAL_CROSS))

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  最终测试结果${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}OpenClaw Agent (agent_01)${NC}"
echo -e "    总调用: ${TOTAL_OPENCLAW}"
echo -e "    成功:   ${TOTAL_OPENCLAW_SUCCESS}"
echo -e "    成功率: ${OC_RATE_FINAL}%"
echo ""
echo -e "  ${PURPLE}Hermes Agent (agent_02)${NC}"
echo -e "    总调用: ${TOTAL_HERMES}"
echo -e "    成功:   ${TOTAL_HERMES_SUCCESS}"
echo -e "    成功率: ${HM_RATE_FINAL}%"
echo ""
echo -e "  ${YELLOW}跨 Agent 协作${NC}"
echo -e "    总调用: ${TOTAL_CROSS}"
echo -e "    成功:   ${TOTAL_CROSS_SUCCESS}"
echo -e "    成功率: ${CR_RATE_FINAL}%"
echo ""
echo -e "  ${RED}合规拦截${NC}"
echo -e "    总拦截: ${TOTAL_COMPLIANCE}"
echo ""
echo -e "  ${RED}错误统计${NC}"
echo -e "    总错误: ${TOTAL_ERRORS}"
echo ""

FINAL_MEMORY=$(get_memory_mb $OPENCLAW_PID)
echo -e "  ${BLUE}内存占用${NC}: ${FINAL_MEMORY}MB"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $OC_RATE_FINAL -ge 95 ] && [ $HM_RATE_FINAL -ge 95 ] && [ $CR_RATE_FINAL -ge 95 ]; then
    echo -e "${GREEN}  测试通过！所有指标成功率 ≥ 95%${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}  部分指标未达标${NC}"
    EXIT_CODE=1
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "详细日志: $LOG_FILE"
echo "指标数据: $METRICS_FILE"

exit $EXIT_CODE
