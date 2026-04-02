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
