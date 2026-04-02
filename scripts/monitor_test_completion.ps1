# OpenClaw Test Completion Monitor
# Monitors test completion and generates report automatically

param(
    [string]$LogDir = "logs\stability_test",
    [string]$OutputDir = "reports"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw Test Completion Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Get-LatestLogFile {
    if (-not (Test-Path $LogDir)) {
        return $null
    }
    
    $logFiles = Get-ChildItem -Path $LogDir -Filter "stability_test_*.log" | Sort-Object LastWriteTime -Descending
    if ($logFiles.Count -eq 0) {
        return $null
    }
    
    return $logFiles[0]
}

function Test-TestComplete {
    param([string]$LogFile)
    
    if (-not (Test-Path $LogFile)) {
        return $false
    }
    
    $logContent = Get-Content $LogFile
    $completionLine = $logContent | Select-String "24-Hour Stability Test Complete!"
    
    return $completionLine -ne $null
}

function Get-TestEndTime {
    param([string]$LogFile)
    
    if (-not (Test-Path $LogFile)) {
        return $null
    }
    
    $logContent = Get-Content $LogFile
    $endLine = $logContent | Select-String "Test End Time:"
    
    if ($endLine) {
        return [DateTime]::ParseExact(($endLine -split "Test End Time: ")[1].Trim(), "yyyy-MM-dd HH:mm:ss", $null)
    }
    
    return $null
}

Write-Host "Starting test completion monitoring..." -ForegroundColor Green
Write-Host "Log directory: $LogDir" -ForegroundColor Gray
Write-Host "Output directory: $OutputDir" -ForegroundColor Gray
Write-Host ""

$checkInterval = 300
$iteration = 0

while ($true) {
    $iteration++
    $latestLogFile = Get-LatestLogFile
    
    if ($null -eq $latestLogFile) {
        Write-Host "[$iteration] Waiting for test to start..." -ForegroundColor Yellow
    }
    else {
        $isComplete = Test-TestComplete -LogFile $latestLogFile.FullName
        $endTime = Get-TestEndTime -LogFile $latestLogFile.FullName
        
        if ($isComplete) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "Test Completed!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Log file: $($latestLogFile.FullName)" -ForegroundColor Cyan
            Write-Host "Completion time: $endTime" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Generating test report..." -ForegroundColor Yellow
            
            try {
                & "$PSScriptRoot\generate_test_report.ps1" -LogDir $LogDir -OutputDir $OutputDir
                
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "Report Generated Successfully" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
                
                $reportFiles = Get-ChildItem -Path $OutputDir -Filter "stability_test_report_*.html" | Sort-Object LastWriteTime -Descending
                if ($reportFiles.Count -gt 0) {
                    Write-Host "Report file: $($reportFiles[0].FullName)" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Opening report in browser..." -ForegroundColor Yellow
                    Start-Process $reportFiles[0].FullName
                }
                
                Write-Host ""
                Write-Host "Monitoring complete!" -ForegroundColor Green
                exit 0
                
            }
            catch {
                Write-Host "Error generating report: $_" -ForegroundColor Red
                exit 1
            }
        }
        else {
            if ($endTime) {
                $remaining = $endTime - (Get-Date)
                if ($remaining.TotalSeconds -gt 0) {
                    Write-Host "[$iteration] Test in progress... Remaining: $($remaining.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
                }
                else {
                    Write-Host "[$iteration] Test should be complete but completion marker not found" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "[$iteration] Test in progress..." -ForegroundColor Cyan
            }
        }
    }
    
    $nextCheck = [DateTime]::Now.AddSeconds($checkInterval).ToString('HH:mm:ss')
    Write-Host "Next check in $checkInterval seconds ($nextCheck)" -ForegroundColor Gray
    Write-Host ""
    
    Start-Sleep -Seconds $checkInterval
}