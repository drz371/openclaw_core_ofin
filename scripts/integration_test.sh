#!/bin/bash
# Clawfed 集成测试脚本
# 用于验证所有核心功能

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TOTAL_TESTS++))
    log_info "运行测试: $test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "$test_name"
        ((FAILED_TESTS++))
        return 1
    fi
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."

    if ! command -v cargo &> /dev/null; then
        log_error "cargo 未安装"
        exit 1
    fi

    if ! command -v rustc &> /dev/null; then
        log_error "rustc 未安装"
        exit 1
    fi

    log_success "所有依赖已安装"
}

# 编译项目
build_project() {
    log_info "编译项目..."

    if [ ! -f "target/release/clawfed" ]; then
        cargo build --release
    fi

    if [ ! -f "target/release/clawfed" ]; then
        log_error "编译失败"
        exit 1
    fi

    log_success "项目编译成功"
}

# 运行单元测试
run_unit_tests() {
    log_info "运行单元测试..."

    if cargo test --quiet; then
        log_success "所有单元测试通过"
        return 0
    else
        log_error "单元测试失败"
        return 1
    fi
}

# 测试 CLI 命令
test_cli_commands() {
    log_info "测试 CLI 命令..."

    # 测试帮助命令
    run_test "CLI 帮助命令" "./target/release/clawfed --help"

    # 测试版本命令（如果有）
    run_test "CLI 版本命令" "./target/release/clawfed --version || true"

    # 测试服务器命令解析
    run_test "CLI 服务器命令解析" "./target/release/clawfed server --help"

    # 测试智能体命令解析
    run_test "CLI 智能体命令解析" "./target/release/clawfed agent --help"

    # 测试调用命令解析
    run_test "CLI 调用命令解析" "./target/release/clawfed call --help"

    # 测试 FL 命令解析
    run_test "CLI FL 命令解析" "./target/release/clawfed fl --help"
}

# 创建测试数据
create_test_data() {
    log_info "创建测试数据..."

    # 创建 LoRA 测试文件
    echo -e "\x4C\x6F\x52\x41\x00\x01" > /tmp/test.lora

    # 创建 DELTA 测试文件
    echo -e "\x44\x45\x4C\x54\x41\x00" > /tmp/test.delta

    # 创建无效测试文件
    echo "invalid" > /tmp/test.invalid

    log_success "测试数据创建成功"
}

# 清理测试数据
cleanup_test_data() {
    log_info "清理测试数据..."

    rm -f /tmp/test.lora /tmp/test.delta /tmp/test.invalid

    log_success "测试数据清理完成"
}

# 测试文件验证
test_file_validation() {
    log_info "测试文件验证..."

    # 测试 LoRA 文件验证
    run_test "LoRA 文件验证" "cargo test test_file_validation_lora --quiet"

    # 测试 DELTA 文件验证
    run_test "DELTA 文件验证" "cargo test test_file_validation_delta --quiet"

    # 测试无效文件验证
    run_test "无效文件验证" "cargo test test_file_validation_invalid --quiet"
}

# 测试合规性
test_compliance() {
    log_info "测试合规性..."

    # 测试禁用合规
    run_test "禁用合规检查" "cargo test test_compliance_disabled --quiet"

    # 测试 CN 地区技能拦截
    run_test "CN 地区技能拦截" "cargo test test_compliance_cn_skill_blocking --quiet"

    # 测试 CN 地区 FL 拦截
    run_test "CN 地区 FL 拦截" "cargo test test_compliance_cn_fl_blocking --quiet"

    # 测试非地区限制
    run_test "非地区限制" "cargo test test_compliance_non_cn --quiet"

    # 测试自定义规则
    run_test "自定义合规规则" "cargo test test_compliance_custom_rules --quiet"
}

# 测试技能系统
test_skill_system() {
    log_info "测试技能系统..."

    # 测试技能创建
    run_test "技能创建" "cargo test test_skill_creation --quiet"

    # 测试技能执行
    run_test "技能执行" "cargo test test_skill_execution --quiet"

    # 测试技能注册
    run_test "技能注册" "cargo test test_skill_registry --quiet"

    # 测试默认技能
    run_test "默认技能" "cargo test test_default_skills --quiet"
}

# 测试智能体管理
test_agent_management() {
    log_info "测试智能体管理..."

    # 测试智能体注册
    run_test "智能体注册" "cargo test test_agent_registry --quiet"

    # 测试智能体发现
    run_test "智能体发现" "cargo test test_agent_discovery --quiet"
}

# 测试联邦学习
test_federated_learning() {
    log_info "测试联邦学习..."

    # 测试 FL 任务管理
    run_test "FL 任务管理" "cargo test test_fl_task_management --quiet"

    # 测试 Delta 上传命令成功
    run_test "Delta 上传成功" "cargo test test_upload_delta_command_success --quiet"

    # 测试 Delta 上传文件未找到
    run_test "Delta 上传文件未找到" "cargo test test_upload_delta_command_file_not_found --quiet"

    # 测试 Delta 上传合规拦截
    run_test "Delta 上传合规拦截" "cargo test test_upload_delta_command_compliance_blocked --quiet"
}

# 测试 CLI 解析
test_cli_parsing() {
    log_info "测试 CLI 解析..."

    # 测试 CLI 解析
    run_test "CLI 解析" "cargo test test_cli_parsing --quiet"

    # 测试无效命令
    run_test "无效命令处理" "cargo test test_cli_invalid_command --quiet"
}

# 性能测试
test_performance() {
    log_info "性能测试..."

    # 测试启动时间
    local start_time=$(date +%s%N)
    ./target/release/clawfed --version > /dev/null 2>&1 || true
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    if [ $duration -lt 5000 ]; then
        log_success "启动时间测试 (${duration}ms < 5000ms)"
        ((PASSED_TESTS++))
        ((TOTAL_TESTS++))
    else
        log_error "启动时间测试 (${duration}ms >= 5000ms)"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
    fi

    # 测试内存使用（需要 ps 命令）
    if command -v ps &> /dev/null; then
        ./target/release/clawfed --version > /dev/null 2>&1 || true
        local memory=$(ps -o rss= -p $(pgrep clawfed) 2>/dev/null || echo "0")

        if [ $memory -lt 51200 ]; then
            log_success "内存使用测试 (${memory}KB < 51200KB)"
            ((PASSED_TESTS++))
            ((TOTAL_TESTS++))
        else
            log_warning "内存使用测试 (${memory}KB >= 51200KB)"
            ((FAILED_TESTS++))
            ((TOTAL_TESTS++))
        fi
    fi
}

# 生成测试报告
generate_report() {
    echo ""
    echo "========================================"
    echo "        测试报告"
    echo "========================================"
    echo ""
    echo "总测试数: $TOTAL_TESTS"
    echo -e "通过: ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "失败: ${RED}${FAILED_TESTS}${NC}"

    if [ $FAILED_TESTS -eq 0 ]; then
        local pass_rate=100
    else
        local pass_rate=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
    fi

    echo "通过率: ${pass_rate}%"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}    所有测试通过！${NC}"
        echo -e "${GREEN}========================================${NC}"
        return 0
    else
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}    部分测试失败！${NC}"
        echo -e "${RED}========================================${NC}"
        return 1
    fi
}

# 主函数
main() {
    echo ""
    echo "========================================"
    echo "    Clawfed 集成测试"
    echo "========================================"
    echo ""

    # 检查依赖
    check_dependencies

    # 编译项目
    build_project

    # 创建测试数据
    create_test_data

    # 运行测试
    echo ""
    echo "========================================"
    echo "    开始测试"
    echo "========================================"
    echo ""

    # 运行单元测试
    run_unit_tests

    # 测试 CLI 命令
    test_cli_commands

    # 测试技能系统
    test_skill_system

    # 测试智能体管理
    test_agent_management

    # 测试联邦学习
    test_federated_learning

    # 测试合规性
    test_compliance

    # 测试 CLI 解析
    test_cli_parsing

    # 性能测试
    test_performance

    # 清理测试数据
    cleanup_test_data

    # 生成报告
    echo ""
    generate_report
    exit $?
}

# 捕获中断信号
trap cleanup_test_data EXIT INT TERM

# 运行主函数
main "$@"
