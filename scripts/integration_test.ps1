# Clawfed 集成测试脚本 (PowerShell)
# 用于验证所有核心功能

$ErrorActionPreference = "Stop"

# 颜色定义
$colors = @{
    Info = "Cyan"
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
}

# 测试计数器
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

# 日志函数
function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $colors.Info
}

function Log-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $colors.Success
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $colors.Error
}

function Log-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $colors.Warning
}

# 测试函数
function Run-Test {
    param(
        [string]$TestName,
        [scriptblock]$TestCommand
    )

    $script:TotalTests++
    Log-Info "运行测试: $TestName"

    try {
        & $TestCommand | Out-Null
        Log-Success "$TestName"
        $script:PassedTests++
        return $true
    } catch {
        Log-Error "$TestName"
        $script:FailedTests++
        return $false
    }
}

# 检查依赖
function Test-Dependencies {
    Log-Info "检查依赖..."

    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Log-Error "cargo 未安装"
        exit 1
    }

    if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
        Log-Error "rustc 未安装"
        exit 1
    }

    Log-Success "所有依赖已安装"
}

# 编译项目
function Build-Project {
    Log-Info "编译项目..."

    if (-not (Test-Path "target\release\clawfed.exe")) {
        cargo build --release
    }

    if (-not (Test-Path "target\release\clawfed.exe")) {
        Log-Error "编译失败"
        exit 1
    }

    Log-Success "项目编译成功"
}

# 运行单元测试
function Invoke-UnitTests {
    Log-Info "运行单元测试..."

    if (cargo test --quiet) {
        Log-Success "所有单元测试通过"
        return $true
    } else {
        Log-Error "单元测试失败"
        return $false
    }
}

# 测试 CLI 命令
function Test-CLICommands {
    Log-Info "测试 CLI 命令..."

    # 测试帮助命令
    Run-Test "CLI 帮助命令" {
        & ".\target\release\clawfed.exe" --help
    }

    # 测试版本命令（如果有）
    Run-Test "CLI 版本命令" {
        & ".\target\release\clawfed.exe" --version 2>$null
    }

    # 测试服务器命令解析
    Run-Test "CLI 服务器命令解析" {
        & ".\target\release\clawfed.exe" server --help
    }

    # 测试智能体命令解析
    Run-Test "CLI 智能体命令解析" {
        & ".\target\release\clawfed.exe" agent --help
    }

    # 测试调用命令解析
    Run-Test "CLI 调用命令解析" {
        & ".\target\release\clawfed.exe" call --help
    }

    # 测试 FL 命令解析
    Run-Test "CLI FL 命令解析" {
        & ".\target\release\clawfed.exe" fl --help
    }
}

# 创建测试数据
function Initialize-TestData {
    Log-Info "创建测试数据..."

    # 创建 LoRA 测试文件
    $loraBytes = [byte[]](0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01)
    [System.IO.File]::WriteAllBytes("$env:TEMP\test.lora", $loraBytes)

    # 创建 DELTA 测试文件
    $deltaBytes = [byte[]](0x44, 0x45, 0x4C, 0x54, 0x41, 0x00)
    [System.IO.File]::WriteAllBytes("$env:TEMP\test.delta", $deltaBytes)

    # 创建无效测试文件
    [System.IO.File]::WriteAllText("$env:TEMP\test.invalid", "invalid")

    Log-Success "测试数据创建成功"
}

# 清理测试数据
function Clear-TestData {
    Log-Info "清理测试数据..."

    Remove-Item "$env:TEMP\test.lora" -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\test.delta" -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\test.invalid" -ErrorAction SilentlyContinue

    Log-Success "测试数据清理完成"
}

# 测试文件验证
function Test-FileValidation {
    Log-Info "测试文件验证..."

    # 测试 LoRA 文件验证
    Run-Test "LoRA 文件验证" {
        cargo test test_file_validation_lora --quiet
    }

    # 测试 DELTA 文件验证
    Run-Test "DELTA 文件验证" {
        cargo test test_file_validation_delta --quiet
    }

    # 测试无效文件验证
    Run-Test "无效文件验证" {
        cargo test test_file_validation_invalid --quiet
    }
}

# 测试合规性
function Test-Compliance {
    Log-Info "测试合规性..."

    # 测试禁用合规
    Run-Test "禁用合规检查" {
        cargo test test_compliance_disabled --quiet
    }

    # 测试 CN 地区技能拦截
    Run-Test "CN 地区技能拦截" {
        cargo test test_compliance_cn_skill_blocking --quiet
    }

    # 测试 CN 地区 FL 拦截
    Run-Test "CN 地区 FL 拦截" {
        cargo test test_compliance_cn_fl_blocking --quiet
    }

    # 测试非地区限制
    Run-Test "非地区限制" {
        cargo test test_compliance_non_cn --quiet
    }

    # 测试自定义规则
    Run-Test "自定义合规规则" {
        cargo test test_compliance_custom_rules --quiet
    }
}

# 测试技能系统
function Test-SkillSystem {
    Log-Info "测试技能系统..."

    # 测试技能创建
    Run-Test "技能创建" {
        cargo test test_skill_creation --quiet
    }

    # 测试技能执行
    Run-Test "技能执行" {
        cargo test test_skill_execution --quiet
    }

    # 测试技能注册
    Run-Test "技能注册" {
        cargo test test_skill_registry --quiet
    }

    # 测试默认技能
    Run-Test "默认技能" {
        cargo test test_default_skills --quiet
    }
}

# 测试智能体管理
function Test-AgentManagement {
    Log-Info "测试智能体管理..."

    # 测试智能体注册
    Run-Test "智能体注册" {
        cargo test test_agent_registry --quiet
    }

    # 测试智能体发现
    Run-Test "智能体发现" {
        cargo test test_agent_discovery --quiet
    }
}

# 测试联邦学习
function Test-FederatedLearning {
    Log-Info "测试联邦学习..."

    # 测试 FL 任务管理
    Run-Test "FL 任务管理" {
        cargo test test_fl_task_management --quiet
    }

    # 测试 Delta 上传命令成功
    Run-Test "Delta 上传成功" {
        cargo test test_upload_delta_command_success --quiet
    }

    # 测试 Delta 上传文件未找到
    Run-Test "Delta 上传文件未找到" {
        cargo test test_upload_delta_command_file_not_found --quiet
    }

    # 测试 Delta 上传合规拦截
    Run-Test "Delta 上传合规拦截" {
        cargo test test_upload_delta_command_compliance_blocked --quiet
    }
}

# 测试 CLI 解析
function Test-CLIParsing {
    Log-Info "测试 CLI 解析..."

    # 测试 CLI 解析
    Run-Test "CLI 解析" {
        cargo test test_cli_parsing --quiet
    }

    # 测试无效命令
    Run-Test "无效命令处理" {
        cargo test test_cli_invalid_command --quiet
    }
}

# 性能测试
function Test-Performance {
    Log-Info "性能测试..."

    # 测试启动时间
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & ".\target\release\clawfed.exe" --version 2>$null | Out-Null
    $stopwatch.Stop()
    $duration = $stopwatch.ElapsedMilliseconds

    if ($duration -lt 5000) {
        Log-Success "启动时间测试 (${duration}ms < 5000ms)"
        $script:PassedTests++
        $script:TotalTests++
    } else {
        Log-Error "启动时间测试 (${duration}ms >= 5000ms)"
        $script:FailedTests++
        $script:TotalTests++
    }

    # 测试内存使用（需要 Get-Process）
    $process = Get-Process -Name "clawfed" -ErrorAction SilentlyContinue
    if ($process) {
        $memoryKB = [math]::Round($process.WorkingSet64 / 1KB, 2)

        if ($memoryKB -lt 51200) {
            Log-Success "内存使用测试 (${memoryKB}KB < 51200KB)"
            $script:PassedTests++
            $script:TotalTests++
        } else {
            Log-Warning "内存使用测试 (${memoryKB}KB >= 51200KB)"
            $script:FailedTests++
            $script:TotalTests++
        }
    }
}

# 生成测试报告
function Show-Report {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "        测试报告" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "总测试数: $script:TotalTests"
    Write-Host "通过: $script:PassedTests" -ForegroundColor $colors.Success
    Write-Host "失败: $script:FailedTests" -ForegroundColor $colors.Error

    if ($script:FailedTests -eq 0) {
        $passRate = 100
    } else {
        $passRate = [math]::Round(($script:PassedTests * 100) / $script:TotalTests, 2)
    }

    Write-Host "通过率: ${passRate}%"
    Write-Host ""

    if ($script:FailedTests -eq 0) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "    所有测试通过！" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        return 0
    } else {
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "    部分测试失败！" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        return 1
    }
}

# 主函数
function Invoke-IntegrationTest {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    Clawfed 集成测试" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 检查依赖
    Test-Dependencies

    # 编译项目
    Build-Project

    # 创建测试数据
    Initialize-TestData

    # 运行测试
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    开始测试" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 运行单元测试
    Invoke-UnitTests

    # 测试 CLI 命令
    Test-CLICommands

    # 测试技能系统
    Test-SkillSystem

    # 测试智能体管理
    Test-AgentManagement

    # 测试联邦学习
    Test-FederatedLearning

    # 测试合规性
    Test-Compliance

    # 测试 CLI 解析
    Test-CLIParsing

    # 性能测试
    Test-Performance

    # 清理测试数据
    Clear-TestData

    # 生成报告
    Write-Host ""
    Show-Report
    exit $LASTEXITCODE
}

# 捕获中断信号
trap {
    Clear-TestData
    exit 1
}

# 运行主函数
Invoke-IntegrationTest
