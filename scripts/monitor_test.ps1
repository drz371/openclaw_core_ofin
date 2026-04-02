# OpenClaw 24-Hour Stability Test Monitor Script
# Real-time monitoring of the stability test progress

param(
    [string]$LogDir = "logs\stability_test",
    [int]$RefreshInterval = 30
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw 24-Hour Stability Test Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to get the latest log file
function Get-LatestLogFile {
    if (-not (Test-Path $LogDir)) {
        return $null
    }
    
    $logFiles = Get-ChildItem -Path $LogDir -Filter "stability_test_*.log" | Sort-Object LastWriteTime -Descending
    if ($logFiles.Count -eq 0) {
        return $null
    }
    
    return $logFiles[0].FullName
}

# Function to parse test statistics from log
function Get-TestStatistics {
    param(
        [string]$LogFile
    )
    
    if (-not (Test-Path $LogFile)) {
        return $null
    }
    
    $stats = @{
        StartTime = $null
        EndTime = $null
        TotalIterations = 0
        SkillCalls = 0
        FLUploads = 0
        ComplianceChecks = 0
        Errors = 0
        SuccessRate = 0
        LastActivity = $null
    }
    
    $logContent = Get-Content $LogFile
    
    # Parse start time
    $startLine = $logContent | Select-String "Test Start Time:"
    if ($startLine) {
        $stats.StartTime = [DateTime]::ParseExact(($startLine -split "Test Start Time: ")[1].Trim(), "yyyy-MM-dd HH:mm:ss", $null)
    }
    
    # Parse end time
    $endLine = $logContent | Select-String "Test End Time:"
    if ($endLine) {
        $stats.EndTime = [DateTime]::ParseExact(($endLine -split "Test End Time: ")[1].Trim(), "yyyy-MM-dd HH:mm:ss", $null)
    }
    
    # Parse statistics from the most recent "Test Statistics" block
    $statLines = $logContent | Select-String "Test Statistics" -Context 0, 10
    if ($statLines) {
        $context = $statLines[-1].Context.PostContext
        foreach ($line in $context) {
            if ($line -match "Total Iterations: (\d+)") {
                $stats.TotalIterations = [int]$matches[1]
            }
            if ($line -match "Skill Calls: (\d+)") {
                $stats.SkillCalls = [int]$matches[1]
            }
            if ($line -match "FL Uploads: (\d+)") {
                $stats.FLUploads = [int]$matches[1]
            }
            if ($line -match "Compliance Checks: (\d+)") {
                $stats.ComplianceChecks = [int]$matches[1]
            }
            if ($line -match "Errors: (\d+)") {
                $stats.Errors = [int]$matches[1]
            }
            if ($line -match "Success Rate: ([\d.]+)%") {
                $stats.SuccessRate = [double]$matches[1]
            }
        }
    }
    
    # Get last activity time
    $lastLogLine = $logContent[-1]
    if ($lastLogLine -match "\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]") {
        $stats.LastActivity = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm:ss", $null)
    }
    
    return $stats
}

# Function to display test status
function Show-TestStatus {
    param(
        [hashtable]$Stats
    )
    
    Clear-Host
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OpenClaw 24-Hour Stability Test Monitor" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($null -eq $Stats) {
        Write-Host "No test data found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Waiting for test to start..." -ForegroundColor Yellow
        return
    }
    
    # Time information
    Write-Host "Time Information:" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Gray
    if ($Stats.StartTime) {
        $elapsed = (Get-Date) - $Stats.StartTime
        Write-Host "Start Time: $($Stats.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Elapsed: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
    }
    
    if ($Stats.EndTime) {
        $remaining = $Stats.EndTime - (Get-Date)
        Write-Host "End Time: $($Stats.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Remaining: $($remaining.ToString('hh\:mm\:ss'))" -ForegroundColor White
        
        # Progress bar
        if ($Stats.StartTime) {
            $totalDuration = $Stats.EndTime - $Stats.StartTime
            $progress = ($elapsed.TotalSeconds / $totalDuration.TotalSeconds) * 100
            Write-Host "Progress: $([math]::Round($progress, 2))%" -ForegroundColor Cyan
            Write-Host "[$('=' * [math]::Floor($progress / 2))$(' ' * (50 - [math]::Floor($progress / 2)))]" -ForegroundColor Cyan
        }
    }
    
    if ($Stats.LastActivity) {
        $idleTime = (Get-Date) - $Stats.LastActivity
        Write-Host "Last Activity: $($Stats.LastActivity.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Idle Time: $($idleTime.ToString('hh\:mm\:ss'))" -ForegroundColor White
    }
    
    Write-Host ""
    
    # Test statistics
    Write-Host "Test Statistics:" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Write-Host "Total Iterations: $($Stats.TotalIterations)" -ForegroundColor White
    Write-Host "Skill Calls: $($Stats.SkillCalls)" -ForegroundColor White
    Write-Host "FL Uploads: $($Stats.FLUploads)" -ForegroundColor White
    Write-Host "Compliance Checks: $($Stats.ComplianceChecks)" -ForegroundColor White
    Write-Host "Errors: $($Stats.Errors)" -ForegroundColor White
    
    if ($Stats.Errors -gt 0) {
        Write-Host "Success Rate: $($Stats.SuccessRate)%" -ForegroundColor Red
    } else {
        Write-Host "Success Rate: $($Stats.SuccessRate)%" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Operations per hour
    if ($Stats.StartTime -and $Stats.TotalIterations -gt 0) {
        $elapsedHours = ((Get-Date) - $Stats.StartTime).TotalHours
        if ($elapsedHours -gt 0) {
            $opsPerHour = $Stats.TotalIterations / $elapsedHours
            Write-Host "Operations per Hour: $([math]::Round($opsPerHour, 2))" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    
    # Status indicator
    if ($Stats.EndTime -and (Get-Date) -ge $Stats.EndTime) {
        Write-Host "Status: COMPLETED" -ForegroundColor Green
    } elseif ($Stats.LastActivity -and ((Get-Date) - $Stats.LastActivity).TotalMinutes -gt 5) {
        Write-Host "Status: IDLE (No activity for > 5 minutes)" -ForegroundColor Yellow
    } else {
        Write-Host "Status: RUNNING" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
    Write-Host "Next update in $RefreshInterval seconds..." -ForegroundColor Gray
}

# Main monitoring loop
Write-Host "Starting test monitor..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

try {
    while ($true) {
        $latestLogFile = Get-LatestLogFile
        $stats = Get-TestStatistics -LogFile $latestLogFile
        Show-TestStatus -Stats $stats
        
        Start-Sleep -Seconds $RefreshInterval
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    Write-Host ""
    Write-Host "Monitoring stopped by user" -ForegroundColor Yellow
} catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
}