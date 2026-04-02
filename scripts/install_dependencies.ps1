# OpenClaw 24小时稳定性测试环境安装脚本
# 自动安装VirtualBox、Vagrant、Docker和Rust

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw 24小时稳定性测试环境安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "请以管理员身份运行此脚本" -ForegroundColor Red
    exit 1
}

# 创建下载目录
$downloadDir = "$env:USERPROFILE\Downloads\OpenClawSetup"
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

Write-Host "下载目录: $downloadDir" -ForegroundColor Green
Write-Host ""

# 1. 安装VirtualBox
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "步骤 1/4: 安装VirtualBox" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$vboxUrl = "https://download.virtualbox.org/virtualbox/7.0.14/VirtualBox-7.0.14-161095-Win.exe"
$vboxInstaller = "$downloadDir\VirtualBox-Setup.exe"

Write-Host "下载VirtualBox..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $vboxUrl -OutFile $vboxInstaller -UseBasicParsing

Write-Host "安装VirtualBox..." -ForegroundColor Yellow
Start-Process -FilePath $vboxInstaller -ArgumentList "--silent", "--msiargs", "/qn /norestart" -Wait

Write-Host "VirtualBox安装完成" -ForegroundColor Green
Write-Host ""

# 2. 安装Vagrant
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "步骤 2/4: 安装Vagrant" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$vagrantUrl = "https://releases.hashicorp.com/vagrant/2.4.1/vagrant_2.4.1_windows_amd64.msi"
$vagrantInstaller = "$downloadDir\Vagrant-Setup.msi"

Write-Host "下载Vagrant..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $vagrantUrl -OutFile $vagrantInstaller -UseBasicParsing

Write-Host "安装Vagrant..." -ForegroundColor Yellow
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $vagrantInstaller, "/qn", "/norestart" -Wait

Write-Host "Vagrant安装完成" -ForegroundColor Green
Write-Host ""

# 3. 安装Docker Desktop
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "步骤 3/4: 安装Docker Desktop" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$dockerInstaller = "$downloadDir\Docker-Desktop-Setup.exe"

Write-Host "下载Docker Desktop..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerInstaller -UseBasicParsing

Write-Host "安装Docker Desktop..." -ForegroundColor Yellow
Start-Process -FilePath $dockerInstaller -ArgumentList "install", "--quiet" -Wait

Write-Host "Docker Desktop安装完成" -ForegroundColor Green
Write-Host ""

# 4. 安装Rust
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "步骤 4/4: 安装Rust" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$rustupUrl = "https://win.rustup.rs/x86_64"
$rustupInstaller = "$downloadDir\rustup-init.exe"

Write-Host "下载Rust..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupInstaller -UseBasicParsing

Write-Host "安装Rust..." -ForegroundColor Yellow
Start-Process -FilePath $rustupInstaller -ArgumentList "-y", "--default-toolchain", "stable", "--profile", "default" -Wait

Write-Host "Rust安装完成" -ForegroundColor Green
Write-Host ""

# 刷新环境变量
Write-Host "刷新环境变量..." -ForegroundColor Yellow
$machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
$env:Path = "$machinePath;$userPath"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "请重启终端或注销后重新登录以使环境变量生效" -ForegroundColor Yellow
Write-Host ""
Write-Host "安装的工具版本:" -ForegroundColor Cyan
Write-Host "- VirtualBox: 7.0.14" -ForegroundColor White
Write-Host "- Vagrant: 2.4.1" -ForegroundColor White
Write-Host "- Docker Desktop: Latest" -ForegroundColor White
Write-Host "- Rust: Latest stable" -ForegroundColor White
Write-Host ""