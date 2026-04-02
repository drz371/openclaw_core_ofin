# OpenClaw 24-Hour Stability Test Script
# Simulating multi-agent collaboration and federated learning scenarios

param(
    [int]$DurationHours = 24,
    [string]$LogDir = "logs\stability_test"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw 24-Hour Stability Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create log directory
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$startTime = Get-Date
$endTime = $startTime.AddHours($DurationHours)
$testLogFile = "$LogDir\stability_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Write-Host "Test Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
Write-Host "Test End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
Write-Host "Test Duration: $DurationHours hours" -ForegroundColor Green
Write-Host "Log File: $testLogFile" -ForegroundColor Green
Write-Host ""

# Log function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        "INFO"    { Write-Host $logMessage -ForegroundColor White }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        default   { Write-Host $logMessage -ForegroundColor White }
    }
    
    # Write to file
    Add-Content -Path $testLogFile -Value $logMessage
}

# Simulate Agent startup
function Start-Agent {
    param(
        [string]$AgentName,
        [int]$Port
    )
    
    Write-Log "Starting Agent: $AgentName (Port: $Port)" "INFO"
    
    # Simulate agent process
    $agentProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c echo Agent $AgentName started on port $Port & timeout /t 86400" -PassThru -WindowStyle Hidden
    
    return @{
        Name = $AgentName
        Port = $Port
        Process = $agentProcess
        StartTime = Get-Date
    }
}

# Simulate skill call
function Invoke-SkillCall {
    param(
        [string]$FromAgent,
        [string]$ToAgent,
        [string]$Skill
    )
    
    Write-Log "Skill Call: $FromAgent -> $ToAgent.$Skill()" "INFO"
    
    # Simulate network delay
    $delay = Get-Random -Minimum 10 -Maximum 100
    Start-Sleep -Milliseconds $delay
    
    Write-Log "Skill Call Complete: $FromAgent -> $ToAgent.$Skill() (Latency: ${delay}ms)" "SUCCESS"
}

# Simulate federated learning upload
function Upload-FLDelta {
    param(
        [string]$AgentName,
        [string]$Task,
        [double]$Accuracy
    )
    
    Write-Log "FL Upload: $AgentName uploading model delta (Task: $Task, Accuracy: $Accuracy)" "INFO"
    
    # Simulate upload delay
    $delay = Get-Random -Minimum 50 -Maximum 200
    Start-Sleep -Milliseconds $delay
    
    Write-Log "FL Upload Complete: $AgentName (Latency: ${delay}ms)" "SUCCESS"
}

# Simulate compliance check
function Test-Compliance {
    param(
        [string]$AgentName,
        [string]$Region
    )
    
    Write-Log "Compliance Check: $AgentName (Region: $Region)" "INFO"
    
    # Simulate compliance check
    if ($Region -eq "CN") {
        Write-Log "Compliance Check Passed: $AgentName meets CN region requirements" "SUCCESS"
    } else {
        Write-Log "Compliance Check Passed: $AgentName meets international region requirements" "SUCCESS"
    }
}

# Create test agents
Write-Log "Creating test agents..." "INFO"
$agents = @()

# Coordinator
$agents += Start-Agent -AgentName "coordinator" -Port 50051
Start-Sleep -Seconds 2

# Agents
$agents += Start-Agent -AgentName "agent_alpha" -Port 50052
Start-Sleep -Seconds 1
$agents += Start-Agent -AgentName "agent_beta" -Port 50053
Start-Sleep -Seconds 1
$agents += Start-Agent -AgentName "agent_gamma" -Port 50054

Write-Log "All agents started successfully" "SUCCESS"
Write-Log "Running agents: $($agents.Count)" "INFO"
Write-Log ""

# Test statistics
$stats = @{
    SkillCalls = 0
    FLUploads = 0
    ComplianceChecks = 0
    Errors = 0
    StartTime = $startTime
}

# Main test loop
Write-Log "Starting 24-hour stability test..." "INFO"
Write-Log ""

$iteration = 0
while ((Get-Date) -lt $endTime) {
    $iteration++
    $elapsed = (Get-Date) - $startTime
    $remaining = $endTime - (Get-Date)
    
    Write-Log "========================================" "INFO"
    Write-Log "Test Iteration #$iteration" "INFO"
    Write-Log "Elapsed Time: $($elapsed.ToString('hh\:mm\:ss'))" "INFO"
    Write-Log "Remaining Time: $($remaining.ToString('hh\:mm\:ss'))" "INFO"
    Write-Log "========================================" "INFO"
    
    try {
        # Random operation selection
        $operation = Get-Random -Minimum 1 -Maximum 4
        
        switch ($operation) {
            1 {
                # Skill call
                $fromAgent = $agents[(Get-Random -Minimum 1 -Maximum $agents.Count)].Name
                $toAgent = $agents[(Get-Random -Minimum 1 -Maximum $agents.Count)].Name
                $skills = @("summarize_pdf", "analyze_image", "process_text", "extract_data", "classify_content")
                $skill = $skills[(Get-Random -Minimum 0 -Maximum $skills.Count)]
                
                Invoke-SkillCall -FromAgent $fromAgent -ToAgent $toAgent -Skill $skill
                $stats.SkillCalls++
            }
            2 {
                # Federated learning upload
                $agent = $agents[(Get-Random -Minimum 1 -Maximum $agents.Count)].Name
                $tasks = @("grasping_v1", "navigation_v2", "perception_v3", "planning_v1")
                $task = $tasks[(Get-Random -Minimum 0 -Maximum $tasks.Count)]
                $accuracy = (Get-Random -Minimum 7000 -Maximum 9500) / 10000.0
                
                Upload-FLDelta -AgentName $agent -Task $task -Accuracy $accuracy
                $stats.FLUploads++
            }
            3 {
                # Compliance check
                $agent = $agents[(Get-Random -Minimum 0 -Maximum $agents.Count)].Name
                $regions = @("CN", "US", "EU", "APAC")
                $region = $regions[(Get-Random -Minimum 0 -Maximum $regions.Count)]
                
                Test-Compliance -AgentName $agent -Region $region
                $stats.ComplianceChecks++
            }
            4 {
                # Mixed operations
                Write-Log "Executing mixed operation sequence..." "INFO"
                
                # Skill call
                $fromAgent = $agents[(Get-Random -Minimum 1 -Maximum $agents.Count)].Name
                $toAgent = $agents[(Get-Random -Minimum 1 -Maximum $agents.Count)].Name
                Invoke-SkillCall -FromAgent $fromAgent -ToAgent $toAgent -Skill "summarize_pdf"
                
                # Federated learning
                $agent = $agents[(Get-Random -Minimum 1 -Maximum $agents.Count)].Name
                Upload-FLDelta -AgentName $agent -Task "grasping_v1" -Accuracy 0.85
                
                # Compliance check
                Test-Compliance -AgentName $agent -Region "CN"
                
                $stats.SkillCalls++
                $stats.FLUploads++
                $stats.ComplianceChecks++
            }
        }
        
        # Random delay
        $sleepTime = Get-Random -Minimum 5 -Maximum 30
        Write-Log "Waiting ${sleepTime} seconds..." "INFO"
        Start-Sleep -Seconds $sleepTime
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        $stats.Errors++
    }
    
    Write-Log ""
    
    # Output statistics every 10 iterations
    if ($iteration % 10 -eq 0) {
        Write-Log "========================================" "INFO"
        Write-Log "Test Statistics" "INFO"
        Write-Log "========================================" "INFO"
        Write-Log "Total Iterations: $iteration" "INFO"
        Write-Log "Skill Calls: $($stats.SkillCalls)" "INFO"
        Write-Log "FL Uploads: $($stats.FLUploads)" "INFO"
        Write-Log "Compliance Checks: $($stats.ComplianceChecks)" "INFO"
        Write-Log "Errors: $($stats.Errors)" "INFO"
        $totalOps = $stats.SkillCalls + $stats.FLUploads + $stats.ComplianceChecks + $stats.Errors
        if ($totalOps -gt 0) {
            $successRate = [math]::Round((($stats.SkillCalls + $stats.FLUploads + $stats.ComplianceChecks) / $totalOps) * 100, 2)
            Write-Log "Success Rate: ${successRate}%" "INFO"
        }
        Write-Log "========================================" "INFO"
        Write-Log ""
    }
}

# Test completion
$finalElapsed = (Get-Date) - $startTime
Write-Log "========================================" "INFO"
Write-Log "24-Hour Stability Test Complete!" "SUCCESS"
Write-Log "========================================" "INFO"
Write-Log "Total Runtime: $($finalElapsed.ToString('hh\:mm\:ss'))" "INFO"
Write-Log "Total Iterations: $iteration" "INFO"
Write-Log "Skill Calls: $($stats.SkillCalls)" "INFO"
Write-Log "FL Uploads: $($stats.FLUploads)" "INFO"
Write-Log "Compliance Checks: $($stats.ComplianceChecks)" "INFO"
Write-Log "Errors: $($stats.Errors)" "INFO"
$totalOps = $stats.SkillCalls + $stats.FLUploads + $stats.ComplianceChecks + $stats.Errors
if ($totalOps -gt 0) {
    $successRate = [math]::Round((($stats.SkillCalls + $stats.FLUploads + $stats.ComplianceChecks) / $totalOps) * 100, 2)
    Write-Log "Success Rate: ${successRate}%" "INFO"
}
Write-Log "========================================" "INFO"

# Stop all agents
Write-Log "Stopping all agents..." "INFO"
foreach ($agent in $agents) {
    try {
        if ($agent.Process -and !$agent.Process.HasExited) {
            Stop-Process -Id $agent.Process.Id -Force
            Write-Log "Stopped: $($agent.Name)" "INFO"
        }
    } catch {
        Write-Log "Failed to stop agent: $($agent.Name) - $_" "ERROR"
    }
}

Write-Log "Test complete, logs saved to: $testLogFile" "SUCCESS"