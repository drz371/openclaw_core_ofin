#!/bin/bash
# Docker 沙盒测试脚本

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

# 检查 Docker
check_docker() {
    log_info "检查 Docker 安装..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi

    log_success "Docker 环境就绪"
}

# 构建镜像
build_images() {
    log_info "构建 Docker 镜像..."

    docker build -f Dockerfile.dev -t clawfed:dev .
    docker build -f Dockerfile.test -t clawfed:test .

    log_success "镜像构建完成"
}

# 运行单元测试
run_unit_tests() {
    log_info "运行单元测试..."

    docker-compose -f docker-compose.test.yml up --abort-on-container-exit

    if [ $? -eq 0 ]; then
        log_success "单元测试通过"
    else
        log_error "单元测试失败"
        exit 1
    fi
}

# 运行集成测试
run_integration_tests() {
    log_info "运行集成测试..."

    docker-compose -f docker-compose.dev.yml up -d

    # 等待服务启动
    sleep 10

    # 运行测试
    ./scripts/integration_test.sh

    # 清理
    docker-compose -f docker-compose.dev.yml down -v

    log_success "集成测试完成"
}

# 安全扫描
security_scan() {
    log_info "运行安全扫描..."

    if command -v trivy &> /dev/null; then
        trivy image clawfed:dev
        log_success "安全扫描完成"
    else
        log_info "Trivy 未安装，跳过安全扫描"
    fi
}

# 主函数
main() {
    echo "========================================"
    echo "    Docker 沙盒测试"
    echo "========================================"
    echo ""

    check_docker
    build_images
    run_unit_tests
    security_scan
    run_integration_tests

    echo ""
    echo "========================================"
    echo "    所有测试完成！"
    echo "========================================"
}

# 运行主函数
main "$@"
