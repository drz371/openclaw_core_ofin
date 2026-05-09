#!/bin/bash
# =====================================================
#   OpenClaw 一键安装运行脚本
#   适用系统：Linux / macOS
#   作者：OpenClaw Team
# =====================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  OpenClaw 一键安装运行脚本${NC}"
echo -e "${BLUE}  让你在 5 分钟内启动多个 AI Agent！${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 检查 Rust
check_rust() {
    echo -e "${BLUE}[1/4] 检查 Rust 环境...${NC}"
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
    echo -e "${BLUE}[2/4] 编译 OpenClaw...${NC}"

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
    echo -e "${BLUE}[3/4] 准备测试数据...${NC}"
    echo -ne '\x4C\x6F\x52\x41\x00\x01' > test_delta.lora
    echo -e "${GREEN}✓ 测试数据已创建 (test_delta.lora)${NC}"
}

# 运行测试
run_test() {
    echo ""
    echo -e "${BLUE}[4/4] 运行功能测试...${NC}"
    echo ""

    # 清理之前的进程
    pkill -f "clawfed server" 2>/dev/null || true
    pkill -f "clawfed agent" 2>/dev/null || true
    sleep 1

    echo -e "${YELLOW}启动协调器（端口 50051）...${NC}"
    ./target/release/clawfed server --addr "0.0.0.0:50051" --agent-id coordinator > /dev/null 2>&1 &
    COORD_PID=$!
    sleep 2

    echo -e "${YELLOW}启动 Agent（端口 50052）...${NC}"
    ./target/release/clawfed agent --server --addr "0.0.0.0:50052" > /dev/null 2>&1 &
    AGENT_PID=$!
    sleep 2

    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  开始测试${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""

    # 测试 1：技能调用
    echo -e "${YELLOW}测试 1: 调用 detect_objects 技能${NC}"
    RESULT=$(./target/release/clawfed call agent_01 detect_objects \
        --addr "http://127.0.0.1:50052" \
        --args '{"url": "https://example.com/image.jpg"}' 2>&1)

    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}✓ detect_objects 调用成功${NC}"
    else
        echo -e "${RED}✗ detect_objects 调用失败${NC}"
    fi

    # 测试 2：PDF 摘要
    echo ""
    echo -e "${YELLOW}测试 2: 调用 summarize_pdf 技能${NC}"
    RESULT=$(./target/release/clawfed call agent_01 summarize_pdf \
        --addr "http://127.0.0.1:50052" \
        --args '{"file": "report.pdf"}' 2>&1)

    if echo "$RESULT" | grep -q "Called skill"; then
        echo -e "${GREEN}✓ summarize_pdf 调用成功${NC}"
    else
        echo -e "${RED}✗ summarize_pdf 调用失败${NC}"
    fi

    # 测试 3：合规拦截
    echo ""
    echo -e "${YELLOW}测试 3: 合规拦截测试（face_detect 应被拦截）${NC}"
    ./target/release/clawfed call agent_01 face_detect \
        --addr "http://127.0.0.1:50052" \
        --args '{}' > /dev/null 2>&1
    EXIT_CODE=$?

    # 合规拦截应该返回非零退出码
    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "${GREEN}✓ 合规拦截正常工作（退出码: $EXIT_CODE）${NC}"
    else
        echo -e "${RED}✗ 合规拦截异常（应该被拦截但返回成功）${NC}"
    fi

    # 清理
    echo ""
    echo -e "${BLUE}清理测试进程...${NC}"
    kill $COORD_PID 2>/dev/null || true
    kill $AGENT_PID 2>/dev/null || true

    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  测试完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${GREEN}  可执行文件：./target/release/clawfed${NC}"
    echo ""
    echo -e "${YELLOW}  常用命令：${NC}"
    echo -e "${NC}  启动协调器:  ./target/release/clawfed server --addr \"0.0.0.0:50051\""
    echo -e "${NC}  启动 Agent:   ./target/release/clawfed agent --server --addr \"0.0.0.0:50052\""
    echo -e "${NC}  调用技能:     ./target/release/clawfed call agent_01 detect_objects --addr \"http://127.0.0.1:50052\" --args '{}'"
    echo ""
}

# 显示帮助
show_help() {
    echo ""
    echo -e "${BLUE}OpenClaw 快速命令：${NC}"
    echo ""
    echo -e "${GREEN}# 启动协调器（终端 1）${NC}"
    echo -e "  ./target/release/clawfed server --addr \"0.0.0.0:50051\""
    echo ""
    echo -e "${GREEN}# 启动 Agent（终端 2）${NC}"
    echo -e "  ./target/release/clawfed agent --server --addr \"0.0.0.0:50052\""
    echo ""
    echo -e "${GREEN}# 调用 Agent 技能（终端 3）${NC}"
    echo -e "  ./target/release/clawfed call agent_01 detect_objects --addr \"http://127.0.0.1:50052\" --args '{\"url\": \"image.jpg\"}'"
    echo ""
    echo -e "${GREEN}# 查看帮助${NC}"
    echo -e "  ./target/release/clawfed --help"
    echo ""
}

# 主程序
main() {
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

    # 运行测试
    run_test

    # 显示帮助
    show_help
}

# 执行
main
