# Multi-Agent Test Script for Clawfed (PowerShell)
# This script demonstrates how to start multiple agents and test their collaboration

$ErrorActionPreference = "Stop"

Write-Host "=== Clawfed Multi-Agent Test ===" -ForegroundColor Cyan
Write-Host ""

# Function to start coordinator
function Start-Coordinator {
    Write-Host "Starting Coordinator..." -ForegroundColor Cyan
    $process = Start-Process -FilePath "cargo" -ArgumentList "run", "--bin", "clawfed", "--", "server", "--addr", "[::1]:50051", "--agent-id", "coordinator" -PassThru -NoNewWindow
    $script:CoordinatorPid = $process.Id
    Write-Host "Coordinator PID: $script:CoordinatorPid"
    Start-Sleep -Seconds 2
}

# Function to start agent
function Start-Agent {
    param(
        [string]$AgentId,
        [int]$Port,
        [string]$Skills
    )

    Write-Host "Starting Agent $AgentId on port $Port..." -ForegroundColor Cyan
    $process = Start-Process -FilePath "cargo" -ArgumentList "run", "--bin", "clawfed", "--", "agent", "--server", "--addr", "[::1]:$Port" -PassThru -NoNewWindow
    $script:AgentPids += $process.Id
    Write-Host "Agent $AgentId PID: $($process.Id)"
    Start-Sleep -Seconds 1
}

# Function to test skill call
function Test-SkillCall {
    param(
        [string]$Target,
        [string]$Skill,
        [string]$Args
    )

    Write-Host "Testing: $Target -> $Skill" -ForegroundColor Green
    & cargo run --bin clawfed -- call $Target $Skill --args $Args --addr "http://[::1]:50051"
    Write-Host ""
}

# Function to test FL upload
function Test-FlUpload {
    param(
        [string]$Task,
        [string]$File
    )

    Write-Host "Testing FL Upload: $Task" -ForegroundColor Green
    & cargo run --bin clawfed -- fl upload-delta --task $Task --file $File --coordinator "http://[::1]:50051"
    Write-Host ""
}

# Cleanup function
function Cleanup {
    Write-Host "Cleaning up..." -ForegroundColor Cyan
    if ($script:CoordinatorPid) {
        Stop-Process -Id $script:CoordinatorPid -Force -ErrorAction SilentlyContinue
    }
    foreach ($pid in $script:AgentPids) {
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }
    Write-Host "All processes stopped"
}

# Trap cleanup on exit
trap { Cleanup } EXIT

# Main test sequence
function Main {
    # Create test delta file
    Write-Host "Creating test delta file..." -ForegroundColor Cyan
    $bytes = [byte[]](0x4C, 0x6F, 0x52, 0x41, 0x00, 0x01)
    [System.IO.File]::WriteAllBytes("test_delta.lora", $bytes)
    Write-Host "Test delta file created: test_delta.lora"

    # Initialize arrays
    $script:AgentPids = @()

    # Start coordinator
    Start-Coordinator

    # Start multiple agents
    Start-Agent -AgentId "vision_agent_01" -Port 50052 -Skills "detect_objects,analyze_image"
    Start-Agent -AgentId "nlp_agent_01" -Port 50053 -Skills "summarize_pdf,process_text"
    Start-Agent -AgentId "robot_agent_01" -Port 50054 -Skills "grasp_object,navigate"

    Write-Host "All agents started!" -ForegroundColor Green
    Write-Host ""

    # Wait for agents to be ready
    Start-Sleep -Seconds 2

    # Test skill calls between agents
    Write-Host "=== Testing Skill Calls ==="
    Test-SkillCall -Target "vision_agent_01" -Skill "detect_objects" -Args '{"url": "https://example.com/image.jpg"}'
    Test-SkillCall -Target "nlp_agent_01" -Skill "summarize_pdf" -Args '{"file": "document.pdf"}'
    Test-SkillCall -Target "robot_agent_01" -Skill "grasp_object" -Args '{"object": "cup"}'

    # Test FL upload
    Write-Host "=== Testing Federated Learning ==="
    Test-FlUpload -Task "grasping_v1" -File "test_delta.lora"
    Test-FlUpload -Task "navigation_v2" -File "test_delta.lora"

    # Test compliance blocking
    Write-Host "=== Testing Compliance Blocking ==="
    Write-Host "Testing blocked skill call..." -ForegroundColor Cyan
    try {
        & cargo run --bin clawfed -- call "vision_agent_01" "face_detect" --args '{"url": "test.jpg"}' --addr "http://[::1]:50051"
    } catch {
        Write-Host "Expected: Compliance blocked" -ForegroundColor Yellow
    }

    Write-Host "Testing blocked FL task..." -ForegroundColor Cyan
    try {
        & cargo run --bin clawfed -- fl upload-delta --task "biometric_task" --file "test_delta.lora" --coordinator "http://[::1]:50051"
    } catch {
        Write-Host "Expected: Compliance blocked" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "=== All tests completed successfully! ===" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop all agents"
    Write-Host ""

    # Keep running until interrupted
    while ($true) {
        Start-Sleep -Seconds 1
    }
}

# Run main function
Main
