# Clawfed 沙盒测试指南

**文档版本**: 1.0.0
**最后更新**: 2026-03-31
**测试范围**: 沙盒环境隔离测试、虚拟机测试

---

## 📋 目录

- [沙盒测试概述](#沙盒测试概述)
- [Docker 沙盒测试](#docker-沙盒测试)
- [虚拟机测试](#虚拟机测试)
- [隔离测试环境](#隔离测试环境)
- [安全测试](#安全测试)
- [沙盒测试脚本](#沙盒测试脚本)
- [故障排查](#故障排查)

---

## 沙盒测试概述

### 什么是沙盒测试？

沙盒测试是在隔离的环境中运行和测试应用程序，以确保：
- **安全性**: 防止恶意代码影响主机系统
- **隔离性**: 测试环境与生产环境分离
- **可重复性**: 可以轻松重建测试环境
- **资源控制**: 限制测试环境的资源使用

### 为什么需要沙盒测试？

1. **安全性**: 防止测试中的错误影响主机系统
2. **一致性**: 确保测试环境的一致性
3. **可移植性**: 验证项目在不同环境中的运行
4. **资源管理**: 限制测试环境的资源使用
5. **快速部署**: 快速创建和销毁测试环境

---

## Docker 沙盒测试

### 1. Docker 环境准备

#### 1.1 安装 Docker

**Linux (Ubuntu/Debian)**:
```bash
# 更新包索引
sudo apt-get update

# 安装依赖
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置稳定版仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# 验证安装
sudo docker run hello-world
```

**macOS**:
```bash
# 使用 Homebrew 安装
brew install --cask docker

# 或下载 Docker Desktop
# https://www.docker.com/products/docker-desktop
```

**Windows**:
```powershell
# 使用 Chocolatey 安装
choco install docker-desktop

# 或下载 Docker Desktop
# https://www.docker.com/products/docker-desktop
```

#### 1.2 验证 Docker 安装

```bash
# 检查 Docker 版本
docker --version
docker-compose --version

# 检查 Docker 服务状态
sudo systemctl status docker  # Linux
# 或
docker info  # 所有平台
```

### 2. Dockerfile 配置

#### 2.1 开发环境 Dockerfile

创建 `Dockerfile.dev`:

```dockerfile
# 开发环境 Dockerfile
FROM rust:1.75-slim as builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制 Cargo 文件
COPY Cargo.toml Cargo.lock ./

# 创建虚拟 src 目录以缓存依赖
RUN mkdir src && echo "fn main() {}" > src/main.rs

# 构建依赖
RUN cargo build --release

# 复制源代码
COPY src ./src
COPY proto ./proto

# 构建项目
RUN cargo build --release

# 运行时镜像
FROM debian:bookworm-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN useradd -m -u 1000 clawfed

# 复制二进制文件
COPY --from=builder /app/target/release/clawfed /usr/local/bin/

# 创建工作目录
RUN mkdir -p /var/lib/clawfed && \
    chown -R clawfed:clawfed /var/lib/clawfed

# 切换用户
USER clawfed
WORKDIR /var/lib/clawfed

# 暴露端口
EXPOSE 50051 50052 50053 50054

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD timeout 3s bash -c 'cat < /dev/null/tcp/localhost/50051 || exit 1' || exit 1

# 默认命令
CMD ["clawfed"]
```

#### 2.2 测试环境 Dockerfile

创建 `Dockerfile.test`:

```dockerfile
# 测试环境 Dockerfile
FROM rust:1.75-slim

# 安装测试依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY . .

# 构建项目
RUN cargo build --release

# 运行测试
CMD ["cargo", "test", "--", "--test-threads=1"]
```

### 3. Docker Compose 配置

#### 3.1 开发环境配置

创建 `docker-compose.dev.yml`:

```yaml
version: '3.8'

services:
  coordinator:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: clawfed-coordinator
    command: server --addr "[::1]:50051" --agent-id coordinator
    ports:
      - "50051:50051"
    volumes:
      - ./config:/var/lib/clawfed/config
      - ./logs:/var/log/clawfed
    environment:
      - RUST_LOG=info
      - RUST_BACKTRACE=1
    networks:
      - clawfed-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "timeout", "3s", "bash", "-c", "cat < /dev/null/tcp/localhost/50051 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

  vision-agent:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: clawfed-vision-agent
    command: agent --server --addr "[::1]:50052"
    ports:
      - "50052:50052"
    depends_on:
      coordinator:
        condition: service_healthy
    environment:
      - RUST_LOG=info
      - COORDINATOR_ADDR=http://coordinator:50051
    networks:
      - clawfed-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

  nlp-agent:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: clawfed-nlp-agent
    command: agent --server --addr "[::1]:50053"
    ports:
      - "50053:50053"
    depends_on:
      coordinator:
        condition: service_healthy
    environment:
      - RUST_LOG=info
      - COORDINATOR_ADDR=http://coordinator:50051
    networks:
      - clawfed-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

  robot-agent:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: clawfed-robot-agent
    command: agent --server --addr "[::1]:50054"
    ports:
      - "50054:50054"
    depends_on:
      coordinator:
        condition: service_healthy
    environment:
      - RUST_LOG=info
      - COORDINATOR_ADDR=http://coordinator:50051
    networks:
      - clawfed-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

networks:
  clawfed-network:
    driver: bridge

volumes:
  config:
  logs:
```

#### 3.2 测试环境配置

创建 `docker-compose.test.yml`:

```yaml
version: '3.8'

services:
  test-runner:
    build:
      context: .
      dockerfile: Dockerfile.test
    container_name: clawfed-test-runner
    volumes:
      - ./target:/app/target
      - ./test-results:/app/test-results
    environment:
      - RUST_LOG=info
      - RUST_BACKTRACE=1
    networks:
      - test-network
    command: cargo test -- --test-threads=1 --nocapture

networks:
  test-network:
    driver: bridge

volumes:
  test-results:
```

### 4. Docker 沙盒测试命令

#### 4.1 构建镜像

```bash
# 构建开发镜像
docker build -f Dockerfile.dev -t clawfed:dev .

# 构建测试镜像
docker build -f Dockerfile.test -t clawfed:test .

# 使用 BuildKit 加速构建
DOCKER_BUILDKIT=1 docker build -f Dockerfile.dev -t clawfed:dev .
```

#### 4.2 运行开发环境

```bash
# 启动所有服务
docker-compose -f docker-compose.dev.yml up -d

# 查看日志
docker-compose -f docker-compose.dev.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.dev.yml logs -f coordinator

# 停止所有服务
docker-compose -f docker-compose.dev.yml down

# 停止并删除卷
docker-compose -f docker-compose.dev.yml down -v
```

#### 4.3 运行测试

```bash
# 运行测试
docker-compose -f docker-compose.test.yml up

# 运行测试并自动清理
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# 查看测试结果
docker-compose -f docker-compose.test.yml logs test-runner

# 清理测试环境
docker-compose -f docker-compose.test.yml down -v
```

#### 4.4 进入容器调试

```bash
# 进入协调者容器
docker exec -it clawfed-coordinator bash

# 进入测试容器
docker exec -it clawfed-test-runner bash

# 在容器中运行命令
docker exec clawfed-coordinator clawfed --help
```

### 5. Docker 资源限制

#### 5.1 CPU 限制

```bash
# 限制 CPU 使用
docker run --cpus="1.5" clawfed:dev

# 限制 CPU 权重
docker run --cpu-shares=512 clawfed:dev
```

#### 5.2 内存限制

```bash
# 限制内存使用
docker run --memory="512m" clawfed:dev

# 限制交换空间
docker run --memory="512m" --memory-swap="1g" clawfed:dev
```

#### 5.3 磁盘限制

```bash
# 限制磁盘写入速度
docker run --device-write-bps /dev/sda:10mb clawfed:dev

# 限制磁盘读取速度
docker run --device-read-bps /dev/sda:10mb clawfed:dev
```

---

## 虚拟机测试

### 1. 虚拟机环境准备

#### 1.1 VirtualBox

**安装 VirtualBox**:

**Linux (Ubuntu/Debian)**:
```bash
# 添加 VirtualBox 仓库
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
sudo sh -c 'echo "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" >> /etc/apt/sources.list.d/virtualbox.list'

# 安装 VirtualBox
sudo apt-get update
sudo apt-get install -y virtualbox-6.1

# 添加用户到 vboxusers 组
sudo usermod -aG vboxusers $USER
```

**macOS**:
```bash
# 使用 Homebrew 安装
brew install --cask virtualbox
```

**Windows**:
```powershell
# 下载并安装
# https://www.virtualbox.org/wiki/Downloads
```

#### 1.2 VMware Workstation

**安装 VMware Workstation**:

**Linux**:
```bash
# 下载并安装
# https://www.vmware.com/products/workstation-pro/workstation-pro-evaluation.html

# 或使用开源版本 (Virtual Machine Manager)
sudo apt-get install virt-manager
```

**Windows/macOS**:
```powershell
# 下载并安装
# https://www.vmware.com/products/workstation-pro/workstation-pro-evaluation.html
```

#### 1.3 Vagrant

**安装 Vagrant**:

**Linux**:
```bash
# 添加 Vagrant 仓库
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 安装 Vagrant
sudo apt-get update && sudo apt-get install vagrant

# 验证安装
vagrant --version
```

**macOS**:
```bash
# 使用 Homebrew 安装
brew install vagrant
```

**Windows**:
```powershell
# 使用 Chocolatey 安装
choco install vagrant
```

### 2. Vagrant 配置

#### 2.1 基础 Vagrantfile

创建 `Vagrantfile`:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # 基础镜像
  config.vm.box = "ubuntu/focal64"

  # 配置虚拟机资源
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
    vb.name = "clawfed-vm"
  end

  # 配置网络
  config.vm.network "private_network", type: "dhcp"
  config.vm.network "forwarded_port", guest: 50051, host: 50051
  config.vm.network "forwarded_port", guest: 50052, host: 50052
  config.vm.network "forwarded_port", guest: 50053, host: 50053
  config.vm.network "forwarded_port", guest: 50054, host: 50054

  # 同步项目目录
  config.vm.synced_folder ".", "/vagrant"

  # 安装依赖
  config.vm.provision "shell", inline: <<-SHELL
    # 更新系统
    apt-get update

    # 安装 Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env

    # 安装依赖
    apt-get install -y pkg-config libssl-dev protobuf-compiler

    # 编译项目
    cd /vagrant
    cargo build --release
  SHELL
end
```

#### 2.2 多节点 Vagrantfile

创建 `Vagrantfile.multi`:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # 协调者节点
  config.vm.define "coordinator" do |coordinator|
    coordinator.vm.box = "ubuntu/focal64"
    coordinator.vm.hostname = "coordinator"
    coordinator.vm.network "private_network", ip: "192.168.56.10"
    coordinator.vm.network "forwarded_port", guest: 50051, host: 50051

    coordinator.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
      vb.name = "clawfed-coordinator"
    end

    coordinator.vm.provision "shell", inline: <<-SHELL
      cd /vagrant
      ./target/release/clawfed server --addr "[::1]:50051" --log-level info &
    SHELL
  end

  # 视觉智能体节点
  config.vm.define "vision-agent" do |vision|
    vision.vm.box = "ubuntu/focal64"
    vision.vm.hostname = "vision-agent"
    vision.vm.network "private_network", ip: "192.168.56.11"
    vision.vm.network "forwarded_port", guest: 50052, host: 50052

    vision.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = 1
      vb.name = "clawfed-vision-agent"
    end

    vision.vm.provision "shell", inline: <<-SHELL
      cd /vagrant
      ./target/release/clawfed agent --server --addr "[::1]:50052" --log-level info &
    SHELL
  end

  # NLP 智能体节点
  config.vm.define "nlp-agent" do |nlp|
    nlp.vm.box = "ubuntu/focal64"
    nlp.vm.hostname = "nlp-agent"
    nlp.vm.network "private_network", ip: "192.168.56.12"
    nlp.vm.network "forwarded_port", guest: 50053, host: 50053

    nlp.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = 1
      vb.name = "clawfed-nlp-agent"
    end

    nlp.vm.provision "shell", inline: <<-SHELL
      cd /vagrant
      ./target/release/clawfed agent --server --addr "[::1]:50053" --log-level info &
    SHELL
  end
end
```

### 3. 虚拟机测试命令

#### 3.1 启动虚拟机

```bash
# 启动虚拟机
vagrant up

# 启动特定虚拟机
vagrant up coordinator

# 启动多节点环境
vagrant up --provision
```

#### 3.2 连接到虚拟机

```bash
# SSH 连接到虚拟机
vagrant ssh

# SSH 连接到特定虚拟机
vagrant ssh coordinator

# 在虚拟机中运行命令
vagrant ssh -c "cd /vagrant && cargo test"
```

#### 3.3 管理虚拟机

```bash
# 查看虚拟机状态
vagrant status

# 暂停虚拟机
vagrant suspend

# 恢复虚拟机
vagrant resume

# 停止虚拟机
vagrant halt

# 销毁虚拟机
vagrant destroy

# 销毁所有虚拟机
vagrant destroy -f
```

#### 3.4 快照管理

```bash
# 创建快照
VBoxManage snapshot clawfed-vm take "before-test"

# 列出快照
VBoxManage snapshot clawfed-vm list

# 恢复快照
VBoxManage snapshot clawfed-vm restore "before-test"

# 删除快照
VBoxManage snapshot clawfed-vm delete "before-test"
```

---

## 隔离测试环境

### 1. 网络隔离

#### 1.1 Docker 网络隔离

```bash
# 创建隔离网络
docker network create --driver bridge --internal isolated-network

# 运行容器在隔离网络中
docker run --network isolated-network clawfed:dev

# 连接容器到隔离网络
docker network connect isolated-network clawfed-coordinator
```

#### 1.2 虚拟机网络隔离

```bash
# 创建仅主机网络
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig "VirtualBox Host-Only Ethernet Adapter" --ip 192.168.56.1 --netmask 255.255.255.0

# 配置虚拟机使用仅主机网络
vagrant ssh -c "sudo ip addr add 192.168.56.10/24 dev eth1"
```

### 2. 文件系统隔离

#### 2.1 Docker 卷隔离

```bash
# 创建隔离卷
docker volume create isolated-data

# 使用隔离卷
docker run -v isolated-data:/var/lib/clawfed clawfed:dev

# 清理隔离卷
docker volume rm isolated-data
```

#### 2.2 虚拟机文件系统隔离

```bash
# 创建独立磁盘
VBoxManage createhd --filename "isolated-disk.vdi" --size 10240

# 附加到虚拟机
VBoxManage storageattach "clawfed-vm" --storagectl "SATA Controller" --port 1 --device 0 --type hdd --medium "isolated-disk.vdi"
```

### 3. 进程隔离

#### 3.1 Docker 进程隔离

```bash
# 使用用户命名空间
docker run --userns=host clawfed:dev

# 使用 PID 命名空间
docker run --pid=host clawfed:dev

# 使用只读根文件系统
docker run --read-only --tmpfs /tmp --tmpfs /var/run clawfed:dev
```

#### 3.2 虚拟机进程隔离

```bash
# 使用 cgroups 限制
vagrant ssh -c "sudo cgcreate -g cpu,memory:/clawfed"
vagrant ssh -c "sudo cgset -r cpu.shares=512 /clawfed"
vagrant ssh -c "sudo cgexec -g cpu,memory:/clawfed ./target/release/clawfed server"
```

---

## 安全测试

### 1. 容器安全扫描

#### 1.1 使用 Trivy 扫描

```bash
# 安装 Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# 扫描镜像
trivy image clawfed:dev

# 扫描文件系统
trivy fs /path/to/project
```

#### 1.2 使用 Docker Bench

```bash
# 运行 Docker Bench Security
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
  -v /var/lib:/var/lib \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/lib/systemd:/usr/lib/systemd \
  -v /etc:/etc --label docker_bench_security \
  docker/docker-bench-security
```

### 2. 虚拟机安全测试

#### 2.1 网络安全测试

```bash
# 扫描开放端口
vagrant ssh -c "sudo netstat -tulpn"

# 检查防火墙规则
vagrant ssh -c "sudo iptables -L -n"

# 测试网络连通性
vagrant ssh -c "ping -c 4 8.8.8.8"
```

#### 2.2 文件系统安全测试

```bash
# 检查文件权限
vagrant ssh -c "find /vagrant -type f -perm /o+w"

# 检查 SUID/SGID 文件
vagrant ssh -c "find /vagrant -type f \( -perm -4000 -o -perm -2000 \)"

# 检查世界可写目录
vagrant ssh -c "find /vagrant -type d -perm /o+w"
```

### 3. 漏洞扫描

#### 3.1 依赖漏洞扫描

```bash
# 使用 cargo audit
cargo install cargo-audit
cargo audit

# 使用 cargo-outdated
cargo install cargo-outdated
cargo outdated
```

#### 3.2 代码安全分析

```bash
# 使用 Clippy 进行静态分析
cargo clippy -- -D warnings

# 使用 rustfmt 检查代码格式
cargo fmt --check
```

---

## 沙盒测试脚本

### 1. Docker 沙盒测试脚本

创建 `scripts/docker_sandbox_test.sh`:

```bash
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
```

### 2. 虚拟机沙盒测试脚本

创建 `scripts/vm_sandbox_test.sh`:

```bash
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
```

---

## 故障排查

### 1. Docker 问题

#### 问题 1: 容器无法启动

**症状**: 容器启动失败或立即退出

**解决方案**:
```bash
# 查看容器日志
docker logs <container_id>

# 查看容器状态
docker ps -a

# 检查资源限制
docker stats

# 增加资源限制
docker run --memory="1g" --cpus="2" clawfed:dev
```

#### 问题 2: 网络连接失败

**症状**: 容器之间无法通信

**解决方案**:
```bash
# 检查网络配置
docker network ls
docker network inspect <network_name>

# 测试网络连通性
docker exec <container_id> ping <other_container_id>

# 重新创建网络
docker network rm <network_name>
docker network create <network_name>
```

#### 问题 3: 权限问题

**症状**: 容器内无法写入文件

**解决方案**:
```bash
# 检查文件权限
docker exec <container_id> ls -la /var/lib/clawfed

# 修改权限
docker exec <container_id> chown -R clawfed:clawfed /var/lib/clawfed

# 使用正确的用户运行
docker run -u 1000:1000 clawfed:dev
```

### 2. 虚拟机问题

#### 问题 1: 虚拟机无法启动

**症状**: Vagrant up 失败

**解决方案**:
```bash
# 检查 VirtualBox 状态
VBoxManage list vms
VBoxManage list runningvms

# 检查系统资源
free -h
df -h

# 清理并重新启动
vagrant destroy -f
vagrant up
```

#### 问题 2: SSH 连接失败

**症状**: vagrant ssh 失败

**解决方案**:
```bash
# 检查虚拟机状态
vagrant status

# 重新加载 SSH 配置
vagrant reload

# 手动 SSH 连接
vagrant ssh-config
ssh -p 2222 vagrant@127.0.0.1
```

#### 问题 3: 网络配置问题

**症状**: 虚拟机无法访问网络

**解决方案**:
```bash
# 检查网络配置
vagrant ssh -c "ip addr show"
vagrant ssh -c "ip route show"

# 重启网络服务
vagrant ssh -c "sudo systemctl restart networking"

# 重新配置网络
vagrant reload --provision
```

---

## 附录

### A. 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `RUST_LOG` | 日志级别 | `info` |
| `RUST_BACKTRACE` | 堆栈跟踪 | `0` |
| `DOCKER_BUILDKIT` | 使用 BuildKit | `0` |

### B. 端口映射

| 服务 | 容器端口 | 主机端口 |
|------|----------|----------|
| Coordinator | 50051 | 50051 |
| Vision Agent | 50052 | 50052 |
| NLP Agent | 50053 | 50053 |
| Robot Agent | 50054 | 50054 |

### C. 资源限制

| 服务 | CPU 限制 | 内存限制 |
|------|----------|----------|
| Coordinator | 1.0 | 512MB |
| Vision Agent | 0.5 | 256MB |
| NLP Agent | 0.5 | 256MB |
| Robot Agent | 0.5 | 256MB |

---

**文档版本**: 1.0.0
**最后更新**: 2026-03-31
**维护者**: OpenClaw Team
