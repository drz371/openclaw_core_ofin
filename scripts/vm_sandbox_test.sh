#!/bin/bash
# 虚拟机沙盒测试脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查 Vagrant
check_vagrant() {
    log_info "检查 Vagrant 安装..."

    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant 未安装"
        exit 1
    fi

    log_success "Vagrant 环境就绪"
}

# 启动虚拟机
start_vm() {
    log_info "启动虚拟机..."

    vagrant up --provision

    log_success "虚拟机启动完成"
}

# 运行测试
run_tests() {
    log_info "在虚拟机中运行测试..."

    vagrant ssh -c "cd /vagrant && cargo test -- --test-threads=1"

    if [ $? -eq 0 ]; then
        log_success "测试通过"
    else
        log_error "测试失败"
        exit 1
    fi
}

# 停止虚拟机
stop_vm() {
    log_info "停止虚拟机..."

    vagrant halt

    log_success "虚拟机已停止"
}

# 主函数
main() {
    echo "========================================"
    echo "    虚拟机沙盒测试"
    echo "========================================"
    echo ""

    check_vagrant
    start_vm
    run_tests
    stop_vm

    echo ""
    echo "========================================"
    echo "    所有测试完成！"
    echo "========================================"
}

# 捕获中断信号
trap stop_vm EXIT INT TERM

# 运行主函数
main "$@"
