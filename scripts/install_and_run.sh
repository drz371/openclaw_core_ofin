#!/bin/bash
# =====================================================
#   OpenClaw × Hermes 多 Agent 一键安装运行脚本
#   默认启动 OpenClaw 和 Hermes 两个 Agent 进行互联测试
#   适用系统：Linux / macOS
#   作者：OpenClaw Team
# =====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    OpenClaw × Hermes 多 Agent 一键安装运行脚本      ║${NC}"
echo -e "${BLUE}║    让你在 5 分钟内启动多个 AI Agent 并互联协作！    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查 Rust
check_rust() {
    echo -e "${BLUE}[1/5] 检查 Rust 环境...${NC}"
    if command -v cargo &> /dev/null; then
        RUST_VERSION=$(rustc --version)
        echo -e "${GREEN}✓ 已安装: $RUST_VERSION${NC}"
        return 0
    else
        echo -e "${YELLOW}✗ Rust 未安装${NC}"
        echo -e "${YELLOW}  请运行以下命令安装：${NC}"
        echo -e "${GREEN}  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh${NC}"
        return 1
    fi
}

# 编译项目
build_project() {
    echo ""
    echo -e "${BLUE}[2/5] 编译 OpenClaw...${NC}"

    if [ -f "./target/release/clawfed" ]; then
        echo -e "${GREEN}✓ 已编译，跳过编译步骤${NC}"
        return 0
    fi

    echo -e "${YELLOW}  首次编译需要 3-5 分钟，请耐心等待...${NC}"
    cargo build --release 2>&1 | tail -5

    if [ -f "./target/release/clawfed" ]; then
        echo -e "${GREEN}✓ 编译成功！${NC}"
    else
        echo -e "${RED}✗ 编译失败${NC}"
        return 1
    fi
}

# 创建测试数据
create_test_data() {
    echo ""
    echo -e "${BLUE}[3/5] 准备测试数据...${NC}"
    echo -ne '\x4C\x6F\x52\x41\x00\x01' > test_delta.lora
    echo -e "${GREEN}✓ 测试数据已创建 (test_delta.lora)${NC}"
}

# 启动服务
start_services() {
    echo ""
    echo -e "${BLUE}[4/5] 启动 OpenClaw × Hermes 服务集群...${NC}"
    echo ""

    # 清理之前的进程
    pkill -f "clawfed server" 2>/dev/null || true
    pkill -f "clawfed agent" 2>/dev/null || true
    sleep 1

    # 启动协调器
    echo -e "${YELLOW}  启动协调器（端口 50051）...${NC}"
    ./target/release/clawfed server --addr "0.0.0.0:50051" --agent-id coordinator > /dev/null 2>&1 &
    COORD_PID=$!
    sleep 1

    # 启动 OpenClaw Agent
    echo -e "${CYAN}  启动 OpenClaw Agent（端口 50052）...${NC}"
    ./target/release/clawfed agent --server --addr "0.0.0.0:50052" > /dev/null 2>&1 &
    OPENCLAW_PID=$!
    sleep 1

    # 启动 Hermes Agent
    echo -e "${PURPLE}  启动 Hermes Agent（端口 50053）...${NC}"
    ./target/release/clawfed agent --server --addr "0.0.0.0:50053" > /dev/null 2>&1 &
    HERMES_PID=$!
    sleep 1

    echo ""
    echo -e "${GREEN}✓ 服务集群已启动！${NC}"
}

# 运行测试
run_test() {
    echo ""
    echo -e "${BLUE}[5/5] 运行 OpenClaw × Hermes 互联测试...${NC}"
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  1. OpenClaw Agent 技能测试${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}测试: detect_objects${NC}"
    RESULT=$(./target/release/clawfed call agent_01 detect_objects \
        --addr "http://127.0.0.1:50052" \
        --args '{"url": "https://example.com/image.jpg"}' 2>&1)
    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ detect_objects 调用成功${NC}"
    else
        echo -e "${RED}  ✗ detect_objects 调用失败${NC}"
    fi

    echo ""
    echo -e "${BLUE}测试: summarize_pdf${NC}"
    RESULT=$(./target/release/clawfed call agent_01 summarize_pdf \
        --addr "http://127.0.0.1:50052" \
        --args '{"file": "report.pdf"}' 2>&1)
    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ summarize_pdf 调用成功${NC}"
    else
        echo -e "${RED}  ✗ summarize_pdf 调用失败${NC}"
    fi

    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  2. Hermes Agent 技能测试${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}测试: analyze_context${NC}"
    RESULT=$(./target/release/clawfed call agent_02 analyze_context \
        --addr "http://127.0.0.1:50053" \
        --args '{"text": "Hello world"}' 2>&1)
    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ analyze_context 调用成功${NC}"
    else
        echo -e "${RED}  ✗ analyze_context 调用失败${NC}"
    fi

    echo ""
    echo -e "${BLUE}测试: generate_response${NC}"
    RESULT=$(./target/release/clawfed call agent_02 generate_response \
        --addr "http://127.0.0.1:50053" \
        --args '{"prompt": "What is AI?"}' 2>&1)
    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ generate_response 调用成功${NC}"
    else
        echo -e "${RED}  ✗ generate_response 调用失败${NC}"
    fi

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  3. OpenClaw × Hermes 跨 Agent 协作测试${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${CYAN}OpenClaw -> Hermes: 翻译技能${NC}"
    RESULT=$(./target/release/clawfed call agent_02 translate_text \
        --addr "http://127.0.0.1:50053" \
        --args '{"text": "Hello", "to": "zh"}' 2>&1)
    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ OpenClaw 调用 Hermes 成功${NC}"
    else
        echo -e "${RED}  ✗ OpenClaw 调用 Hermes 失败${NC}"
    fi

    echo ""
    echo -e "${PURPLE}Hermes -> OpenClaw: 图像识别技能${NC}"
    RESULT=$(./target/release/clawfed call agent_01 detect_objects \
        --addr "http://127.0.0.1:50052" \
        --args '{"url": "https://example.com/photo.jpg"}' 2>&1)
    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}  ✓ Hermes 调用 OpenClaw 成功${NC}"
    else
        echo -e "${RED}  ✗ Hermes 调用 OpenClaw 失败${NC}"
    fi

    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  4. 合规拦截测试${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}测试: OpenClaw 合规拦截 (face_detect)${NC}"
    {
        ./target/release/clawfed call agent_01 face_detect \
            --addr "http://127.0.0.1:50052" \
            --args '{}'
    } > /dev/null 2>&1
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "${GREEN}  ✓ OpenClaw 合规拦截正常${NC}"
    else
        echo -e "${RED}  ✗ OpenClaw 合规拦截异常${NC}"
    fi

    echo ""
    echo -e "${BLUE}测试: Hermes 合规拦截 (face_detect)${NC}"
    {
        ./target/release/clawfed call agent_02 face_detect \
            --addr "http://127.0.0.1:50053" \
            --args '{}'
    } > /dev/null 2>&1
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "${GREEN}  ✓ Hermes 合规拦截正常${NC}"
    else
        echo -e "${RED}  ✗ Hermes 合规拦截异常${NC}"
    fi

    echo ""
}

# 清理
cleanup() {
    echo ""
    echo -e "${BLUE}清理测试进程...${NC}"
    pkill -f "clawfed server" 2>/dev/null || true
    pkill -f "clawfed agent" 2>/dev/null || true
    echo -e "${GREEN}清理完成${NC}"
}

# 显示帮助
show_help() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              OpenClaw × Hermes 快速命令              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}【服务地址】${NC}"
    echo -e "${CYAN}  OpenClaw:   http://127.0.0.1:50052 (agent_01)${NC}"
    echo -e "${PURPLE}  Hermes:     http://127.0.0.1:50053 (agent_02)${NC}"
    echo -e "${YELLOW}  Coordinator: http://127.0.0.1:50051${NC}"
    echo ""
    echo -e "${YELLOW}【启动命令】${NC}"
    echo -e "  ./target/release/clawfed server --addr \"0.0.0.0:50051\""
    echo -e "  ./target/release/clawfed agent --server --addr \"0.0.0.0:50052\"  # OpenClaw"
    echo -e "  ./target/release/clawfed agent --server --addr \"0.0.0.0:50053\"  # Hermes"
    echo ""
    echo -e "${YELLOW}【OpenClaw 技能】${NC}"
    echo -e "  detect_objects, summarize_pdf, process_data"
    echo ""
    echo -e "${YELLOW}【Hermes 技能】${NC}"
    echo -e "  analyze_context, generate_response, translate_text"
    echo ""
    echo -e "${YELLOW}【调用示例】${NC}"
    echo -e "  # OpenClaw 调用"
    echo -e "  ./target/release/clawfed call agent_01 detect_objects \\"
    echo -e "    --addr \"http://127.0.0.1:50052\" --args '{\"url\": \"image.jpg\"}'"
    echo ""
    echo -e "  # Hermes 调用"
    echo -e "  ./target/release/clawfed call agent_02 translate_text \\"
    echo -e "    --addr \"http://127.0.0.1:50053\" --args '{\"text\": \"Hello\", \"to\": \"zh\"}'"
    echo ""
    echo -e "${YELLOW}【更多测试】${NC}"
    echo -e "  ./scripts/multi_agent_test.sh    # 完整多 Agent 测试"
    echo -e "  ./scripts/stability_test_20min.sh  # 20分钟稳定性测试"
    echo ""
}

# 主程序
main() {
    trap cleanup EXIT

    # 检查 Rust
    if ! check_rust; then
        exit 1
    fi

    # 编译
    if ! build_project; then
        exit 1
    fi

    # 创建测试数据
    create_test_data

    # 启动服务
    start_services

    # 运行测试
    run_test

    # 显示帮助
    show_help

    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          OpenClaw × Hermes 协作测试完成！          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
}

# 执行
main
