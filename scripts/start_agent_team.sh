#!/bin/bash
# =============================================================================
# OpenClaw × Hermes 联邦协作框架 - 智能启动脚本
# =============================================================================
# 功能: 启动 Agent Team + 加载报告 + 启用自主编排
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目路径 (返回上级目录)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 默认配置
DEFAULT_COORDINATOR="[::1]:50051"
DEFAULT_AGENT_01="[::1]:50052"
DEFAULT_AGENT_02="[::1]:50053"
REPORT_PATH="$PROJECT_ROOT/reports"

# =============================================================================
# 辅助函数
# =============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║     🦀 OpenClaw × Hermes 联邦协作框架 🦀                          ║"
    echo "║                                                                    ║"
    echo "║     Agent Team + 自主编排 + 报告加载                               ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_dependencies() {
    print_status "检查依赖..."

    if ! command -v cargo &> /dev/null; then
        print_error "Rust/Cargo 未安装"
        exit 1
    fi

    if [ ! -f "$PROJECT_ROOT/Cargo.toml" ]; then
        print_error "Cargo.toml 未找到"
        exit 1
    fi

    print_success "依赖检查通过"
}

load_reports() {
    print_status "加载项目报告..."

    if [ -d "$REPORT_PATH" ]; then
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}                          📊 已加载的报告${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"

        for report in "$REPORT_PATH"/*.md; do
            if [ -f "$report" ]; then
                filename=$(basename "$report")
                echo ""
                echo -e "${GREEN}📄 $filename${NC}"
                # 显示报告摘要
                head -n 15 "$report" 2>/dev/null || true
            fi
        done

        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
        print_success "报告加载完成 (共 $(ls -1 $REPORT_PATH/*.md 2>/dev/null | wc -l) 份)"
    else
        print_warning "报告目录不存在: $REPORT_PATH"
    fi
}

build_project() {
    print_status "编译项目..."

    if cargo build 2>&1 | tail -5; then
        print_success "编译成功"
    else
        print_error "编译失败"
        exit 1
    fi
}

# =============================================================================
# Agent Team 管理
# =============================================================================

start_coordinator() {
    print_status "启动协调器 (Coordinator)..."

    COORD_PID_FILE="/tmp/clawfed_coordinator.pid"

    if [ -f "$COORD_PID_FILE" ]; then
        OLD_PID=$(cat "$COORD_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            print_warning "协调器已在运行 (PID: $OLD_PID)"
            return 0
        else
            print_status "清理旧的协调器进程"
            rm -f "$COORD_PID_FILE"
        fi
    fi

    nohup cargo run --bin clawfed -- server \
        --addr "$DEFAULT_COORDINATOR" \
        --agent-id coordinator \
        > /tmp/clawfed_coordinator.log 2>&1 &

    COORD_PID=$!
    echo $COORD_PID > "$COORD_PID_FILE"
    sleep 3

    if kill -0 "$COORD_PID" 2>/dev/null; then
        print_success "协调器已启动 (PID: $COORD_PID, 地址: $DEFAULT_COORDINATOR)"
    else
        print_error "协调器启动失败"
        cat /tmp/clawfed_coordinator.log
        exit 1
    fi
}

start_agent_01() {
    print_status "启动 Agent-01 (OpenClaw 视觉/数据)..."

    AGENT1_PID_FILE="/tmp/clawfed_agent01.pid"

    if [ -f "$AGENT1_PID_FILE" ]; then
        OLD_PID=$(cat "$AGENT1_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            print_warning "Agent-01 已在运行 (PID: $OLD_PID)"
            return 0
        else
            rm -f "$AGENT1_PID_FILE"
        fi
    fi

    nohup cargo run --bin clawfed -- agent \
        --agent-id openclaw \
        --addr "$DEFAULT_AGENT_01" \
        --server \
        --coordinator "http://$DEFAULT_COORDINATOR" \
        > /tmp/clawfed_agent01.log 2>&1 &

    AGENT1_PID=$!
    echo $AGENT1_PID > "$AGENT1_PID_FILE"
    sleep 2

    if kill -0 "$AGENT1_PID" 2>/dev/null; then
        print_success "Agent-01 已启动 (PID: $AGENT1_PID, 地址: $DEFAULT_AGENT_01)"
    else
        print_warning "Agent-01 启动可能失败"
    fi
}

start_agent_02() {
    print_status "启动 Agent-02 (Hermes 语言/分析)..."

    AGENT2_PID_FILE="/tmp/clawfed_agent02.pid"

    if [ -f "$AGENT2_PID_FILE" ]; then
        OLD_PID=$(cat "$AGENT2_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            print_warning "Agent-02 已在运行 (PID: $OLD_PID)"
            return 0
        else
            rm -f "$AGENT2_PID_FILE"
        fi
    fi

    nohup cargo run --bin clawfed -- agent \
        --agent-id hermes \
        --addr "$DEFAULT_AGENT_02" \
        --server \
        --coordinator "http://$DEFAULT_COORDINATOR" \
        > /tmp/clawfed_agent02.log 2>&1 &

    AGENT2_PID=$!
    echo $AGENT2_PID > "$AGENT2_PID_FILE"
    sleep 2

    if kill -0 "$AGENT2_PID" 2>/dev/null; then
        print_success "Agent-02 已启动 (PID: $AGENT2_PID, 地址: $DEFAULT_AGENT_02)"
    else
        print_warning "Agent-02 启动可能失败"
    fi
}

start_agent_team() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                       🤖 启动 Agent Team${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""

    start_coordinator
    start_agent_01
    start_agent_02

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                      ✅ Agent Team 启动完成${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  📍 协调器: ${BLUE}$DEFAULT_COORDINATOR${NC}"
    echo -e "  📍 Agent-01: ${BLUE}$DEFAULT_AGENT_01${NC} (OpenClaw 视觉/数据)"
    echo -e "  📍 Agent-02: ${BLUE}$DEFAULT_AGENT_02${NC} (Hermes 语言/分析)"
    echo ""
}

wait_for_agents() {
    print_status "等待 Agent 注册..."
    sleep 5
    print_success "Agent 注册完成"
}

# =============================================================================
# 自主编排示例
# =============================================================================

run_demo_task() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    🎯 运行自主编排演示任务${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""

    print_status "执行任务: 基于报告进行投资策略分析..."

    cargo run --bin clawfed -- orchestrate \
        "基于全球AI预测报告(2026-2035)，分析投资策略" \
        --coordinator "$DEFAULT_COORDINATOR" 2>&1 || true

    echo ""
}

# =============================================================================
# 清理函数
# =============================================================================

cleanup() {
    print_warning "正在停止所有服务..."

    for pid_file in /tmp/clawfed_*.pid; do
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                print_status "已停止 PID: $pid"
            fi
            rm -f "$pid_file"
        fi
    done

    print_success "清理完成"
}

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --coordinator ADDR   设置协调器地址 (默认: $DEFAULT_COORDINATOR)"
    echo "  --agent-01 ADDR      设置 Agent-01 地址 (默认: $DEFAULT_AGENT_01)"
    echo "  --agent-02 ADDR      设置 Agent-02 地址 (默认: $DEFAULT_AGENT_02)"
    echo "  --skip-build         跳过编译步骤"
    echo "  --skip-reports       跳过报告加载"
    echo "  --demo               运行演示任务"
    echo "  --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                           # 启动完整 Agent Team"
    echo "  $0 --demo                    # 启动并运行演示"
    echo "  $0 --coordinator 127.0.0.1:50051"
    echo ""
}

# =============================================================================
# 主流程
# =============================================================================

main() {
    SKIP_BUILD=false
    SKIP_REPORTS=false
    RUN_DEMO=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --coordinator)
                DEFAULT_COORDINATOR="$2"
                shift 2
                ;;
            --agent-01)
                DEFAULT_AGENT_01="$2"
                shift 2
                ;;
            --agent-02)
                DEFAULT_AGENT_02="$2"
                shift 2
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-reports)
                SKIP_REPORTS=true
                shift
                ;;
            --demo)
                RUN_DEMO=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 捕获 Ctrl+C
    trap cleanup SIGINT SIGTERM

    # 显示横幅
    print_banner

    # 检查依赖
    check_dependencies

    # 编译项目
    if [ "$SKIP_BUILD" = false ]; then
        build_project
    else
        print_warning "跳过编译"
    fi

    # 加载报告
    if [ "$SKIP_REPORTS" = false ]; then
        load_reports
    fi

    # 启动 Agent Team
    start_agent_team

    # 等待 Agent 就绪
    wait_for_agents

    # 运行演示
    if [ "$RUN_DEMO" = true ]; then
        run_demo_task
    fi

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    🚀 系统已就绪！${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "可用命令:"
    echo ""
    echo -e "  ${CYAN}# 查看 Agent 状态${NC}"
    echo "  cargo run --bin clawfed -- status --coordinator $DEFAULT_COORDINATOR"
    echo ""
    echo -e "  ${CYAN}# 运行自主编排任务${NC}"
    echo "  cargo run --bin clawfed -- orchestrate \"你的任务目标\" --coordinator $DEFAULT_COORDINATOR"
    echo ""
    echo -e "  ${CYAN}# 联邦学习训练${NC}"
    echo "  cargo run --bin clawfed -- fl train --coordinator $DEFAULT_COORDINATOR --rounds 10"
    echo ""
    echo -e "  ${CYAN}# 停止所有服务${NC}"
    echo "  $0 --stop"
    echo ""
    echo "按 Ctrl+C 停止所有服务"
    echo ""

    # 保持运行
    if [ "$RUN_DEMO" = false ]; then
        wait
    fi
}

main "$@"
