# PowerShell Agent Team Startup Script for Windows
# =============================================================================
# 功能: 启动 Agent Team + 加载报告 + 启用自主编排
# =============================================================================

param(
    [string]$Coordinator = "[::1]:50051",
    [string]$Agent01 = "[::1]:50052",
    [string]$Agent02 = "[::1]:50053",
    [switch]$SkipBuild,
    [switch]$SkipReports,
    [switch]$Demo,
    [switch]$Help
)

$ProjectRoot = $PSScriptRoot
$ReportPath = Join-Path $ProjectRoot "reports"

# Color codes
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[0;34m"
$CYAN = "`e[0;36m"
$NC = "`e[0m"

function Write-Banner {
    Write-Host ""
    Write-Host "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    Write-Host "${CYAN}║                                                                    ║${NC}"
    Write-Host "${CYAN}║     OpenClaw x Hermes 联邦协作框架                              ║${NC}"
    Write-Host "${CYAN}║                                                                    ║${NC}"
    Write-Host "${CYAN}║     Agent Team + 自主编排 + 报告加载                           ║${NC}"
    Write-Host "${CYAN}║                                                                    ║${NC}"
    Write-Host "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    Write-Host ""
}

function Write-Info { Write-Host "${BLUE}[INFO]${NC} $args" }
function Write-Success { Write-Host "${GREEN}[OK]${NC} $args" }
function Write-Warning { Write-Host "${YELLOW}[WARN]${NC} $args" }
function Write-Error { Write-Host "${RED}[ERROR]${NC} $args" }

function Show-Help {
    Write-Host @"
用法: .\start_agent_team.ps1 [选项]

选项:
  -Coordinator ADDR    设置协调器地址 (默认: $Coordinator)
  -Agent01 ADDR       设置 Agent-01 地址 (默认: $Agent01)
  -Agent02 ADDR       设置 Agent-02 地址 (默认: $Agent02)
  -SkipBuild          跳过编译步骤
  -SkipReports        跳过报告加载
  -Demo               运行演示任务
  -Help               显示此帮助信息

示例:
  .\start_agent_team.ps1              # 启动完整 Agent Team
  .\start_agent_team.ps1 -Demo         # 启动并运行演示

"@
}

if ($Help) {
    Show-Help
    exit 0
}

# Change to project directory
Set-Location $ProjectRoot

# Show banner
Write-Banner

# Check dependencies
Write-Info "检查依赖..."
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "Rust/Cargo 未安装"
    exit 1
}
Write-Success "依赖检查通过"

# Build project
if (-not $SkipBuild) {
    Write-Info "编译项目..."
    cargo build 2>&1 | Select-Object -Last 5
    Write-Success "编译成功"
} else {
    Write-Warning "跳过编译"
}

# Load reports
if (-not $SkipReports) {
    Write-Info "加载项目报告..."

    if (Test-Path $ReportPath) {
        Write-Host ""
        Write-Host "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
        Write-Host "${YELLOW}                          报告加载${NC}"
        Write-Host "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"

        Get-ChildItem "$ReportPath\*.md" | ForEach-Object {
            Write-Host ""
            Write-Host "${GREEN}📄 $($_.Name)${NC}"
            Get-Content $_.FullName | Select-Object -First 15
        }

        Write-Host ""
        $reportCount = (Get-ChildItem "$ReportPath\*.md").Count
        Write-Success "报告加载完成 (共 $reportCount 份)"
    }
}

# Start Coordinator
Write-Info "启动协调器 (Coordinator)..."
$coordJob = Start-Job -ScriptBlock {
    Set-Location $using:ProjectRoot
    cargo run --bin clawfed -- server --addr $using:Coordinator --agent-id coordinator
} -Name "Coordinator"
Write-Success "协调器已在后台启动 (Job ID: $($coordJob.Id))"
Start-Sleep -Seconds 3

# Start Agent-01
Write-Info "启动 Agent-01 (OpenClaw 视觉/数据)..."
$agent1Job = Start-Job -ScriptBlock {
    Set-Location $using:ProjectRoot
    cargo run --bin clawfed -- agent --agent-id agent_01 --addr $using:Agent01 --coordinator $using:Coordinator --config ""
} -Name "Agent-01"
Write-Success "Agent-01 已在后台启动 (Job ID: $($agent1Job.Id))"
Start-Sleep -Seconds 2

# Start Agent-02
Write-Info "启动 Agent-02 (Hermes 语言/分析)..."
$agent2Job = Start-Job -ScriptBlock {
    Set-Location $using:ProjectRoot
    cargo run --bin clawfed -- agent --agent-id agent_02 --addr $using:Agent02 --coordinator $using:Coordinator --config ""
} -Name "Agent-02"
Write-Success "Agent-02 已在后台启动 (Job ID: $($agent2Job.Id))"
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
Write-Host "${GREEN}                      Agent Team 启动完成${NC}"
Write-Host "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
Write-Host ""
Write-Host "  📍 协调器: ${BLUE}$Coordinator${NC}"
Write-Host "  📍 Agent-01: ${BLUE}$Agent01${NC} (OpenClaw 视觉/数据)"
Write-Host "  📍 Agent-02: ${BLUE}$Agent02${NC} (Hermes 语言/分析)"
Write-Host ""

# Wait for agents
Write-Info "等待 Agent 注册..."
Start-Sleep -Seconds 5
Write-Success "Agent 注册完成"

# Run demo if requested
if ($Demo) {
    Write-Host ""
    Write-Host "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    Write-Host "${CYAN}                    运行自主编排演示任务${NC}"
    Write-Host "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    Write-Host ""

    cargo run --bin clawfed -- orchestrate "基于全球AI预测报告(2026-2035)，分析投资策略" --coordinator $Coordinator
}

Write-Host ""
Write-Host "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
Write-Host "${GREEN}                    系统已就绪！${NC}"
Write-Host "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
Write-Host ""
Write-Host "可用命令:"
Write-Host ""
Write-Host "  ${CYAN}# 查看 Agent 状态${NC}"
Write-Host "  cargo run --bin clawfed -- status --coordinator $Coordinator"
Write-Host ""
Write-Host "  ${CYAN}# 运行自主编排任务${NC}"
Write-Host "  cargo run --bin clawfed -- orchestrate `"你的任务目标`" --coordinator $Coordinator"
Write-Host ""

# Cleanup on exit
$jobs = Get-Job
Write-Host "后台运行的 Jobs:"
$jobs | Format-Table -AutoSize

Write-Host "按 Ctrl+C 停止所有服务，或运行以下命令:"
Write-Host "  Get-Job | Stop-Job; Get-Job | Remove-Job"
Write-Host ""

# Wait for jobs
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Warning "正在停止所有服务..."
    Get-Job | Stop-Job
    Get-Job | Remove-Job
    Write-Success "清理完成"
}
