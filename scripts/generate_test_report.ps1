# OpenClaw 24-Hour Stability Test Report Generator
# Generates comprehensive test reports from log files

param(
    [string]$LogDir = "logs\stability_test",
    [string]$OutputDir = "reports"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw 24-Hour Stability Test Report" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Function to get the latest log file
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

# Function to parse test statistics
function Get-TestStatistics {
    param(
        [string]$LogFile
    )
    
    if (-not (Test-Path $LogFile)) {
        return $null
    }
    
    $logContent = Get-Content $LogFile
    
    $stats = @{
        StartTime = $null
        EndTime = $null
        Duration = $null
        TotalIterations = 0
        SkillCalls = 0
        FLUploads = 0
        ComplianceChecks = 0
        Errors = 0
        SuccessRate = 0
        OperationsPerHour = 0
        ErrorLog = @()
        SkillCallLatencies = @()
        FLUploadLatencies = @()
        ComplianceChecksByRegion = @{}
    }
    
    # Parse start and end times
    $startLine = $logContent | Select-String "Test Start Time:"
    if ($startLine) {
        $stats.StartTime = [DateTime]::ParseExact(($startLine -split "Test Start Time: ")[1].Trim(), "yyyy-MM-dd HH:mm:ss", $null)
    }
    
    $endLine = $logContent | Select-String "Test End Time:"
    if ($endLine) {
        $stats.EndTime = [DateTime]::ParseExact(($endLine -split "Test End Time: ")[1].Trim(), "yyyy-MM-dd HH:mm:ss", $null)
    }
    
    if ($stats.StartTime -and $stats.EndTime) {
        $stats.Duration = $stats.EndTime - $stats.StartTime
    }
    
    # Parse final statistics
    $finalStatsLines = $logContent | Select-String "24-Hour Stability Test Complete!" -Context 0, 20
    if ($finalStatsLines) {
        $context = $finalStatsLines[-1].Context.PostContext
        foreach ($line in $context) {
            if ($line -match "Total Runtime: ([\d:]+)") {
                # Duration already calculated
            }
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
    
    # Calculate operations per hour
    if ($stats.Duration -and $stats.TotalIterations -gt 0) {
        $stats.OperationsPerHour = $stats.TotalIterations / $stats.Duration.TotalHours
    }
    
    # Parse latencies
    $latencyLines = $logContent | Select-String "Latency: (\d+)ms"
    foreach ($line in $latencyLines) {
        if ($line -match "Skill Call.*Latency: (\d+)ms") {
            $stats.SkillCallLatencies += [int]$matches[1]
        }
        if ($line -match "FL Upload.*Latency: (\d+)ms") {
            $stats.FLUploadLatencies += [int]$matches[1]
        }
    }
    
    # Parse compliance checks by region
    $complianceLines = $logContent | Select-String "Compliance Check:.*Region: (\w+)"
    foreach ($line in $complianceLines) {
        if ($line -match "Region: (\w+)") {
            $region = $matches[1]
            if (-not $stats.ComplianceChecksByRegion.ContainsKey($region)) {
                $stats.ComplianceChecksByRegion[$region] = 0
            }
            $stats.ComplianceChecksByRegion[$region]++
        }
    }
    
    # Parse errors
    $errorLines = $logContent | Select-String "\[ERROR\]"
    foreach ($line in $errorLines) {
        $stats.ErrorLog += $line.ToString()
    }
    
    return $stats
}

# Function to calculate statistics
function Get-LatencyStats {
    param(
        [int[]]$Latencies
    )
    
    if ($Latencies.Count -eq 0) {
        return $null
    }
    
    $sorted = $Latencies | Sort-Object
    $avg = $Latencies | Measure-Object -Average | Select-Object -ExpandProperty Average
    $min = $sorted[0]
    $max = $sorted[-1]
    $median = $sorted[[math]::Floor($sorted.Count / 2)]
    $p95 = $sorted[[math]::Floor($sorted.Count * 0.95)]
    $p99 = $sorted[[math]::Floor($sorted.Count * 0.99)]
    
    return @{
        Average = [math]::Round($avg, 2)
        Min = $min
        Max = $max
        Median = $median
        P95 = $p95
        P99 = $p99
        Count = $Latencies.Count
    }
}

# Generate HTML report
function Generate-HTMLReport {
    param(
        [hashtable]$Stats,
        [string]$LogFile,
        [string]$OutputFile
    )
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenClaw 24-Hour Stability Test Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .summary-card h3 {
            margin: 0 0 10px 0;
            font-size: 14px;
            opacity: 0.9;
        }
        .summary-card .value {
            font-size: 32px;
            font-weight: bold;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .success {
            color: #27ae60;
            font-weight: bold;
        }
        .error {
            color: #e74c3c;
            font-weight: bold;
        }
        .warning {
            color: #f39c12;
            font-weight: bold;
        }
        .info {
            color: #3498db;
            font-weight: bold;
        }
        .log-entry {
            font-family: monospace;
            background-color: #f8f9fa;
            padding: 10px;
            margin: 5px 0;
            border-left: 3px solid #3498db;
        }
        .error-log {
            color: #e74c3c;
            border-left-color: #e74c3c;
        }
        .timestamp {
            color: #7f8c8d;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>OpenClaw 24-Hour Stability Test Report</h1>
        
        <h2>Test Summary</h2>
        <div class="summary">
            <div class="summary-card">
                <h3>Duration</h3>
                <div class="value">$($Stats.Duration.ToString('hh\:mm\:ss'))</div>
            </div>
            <div class="summary-card">
                <h3>Total Iterations</h3>
                <div class="value">$($Stats.TotalIterations)</div>
            </div>
            <div class="summary-card">
                <h3>Success Rate</h3>
                <div class="value">$($Stats.SuccessRate)%</div>
            </div>
            <div class="summary-card">
                <h3>Operations/Hour</h3>
                <div class="value">$([math]::Round($Stats.OperationsPerHour, 2))</div>
            </div>
        </div>
        
        <h2>Test Details</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Start Time</td>
                <td>$($Stats.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>
            </tr>
            <tr>
                <td>End Time</td>
                <td>$($Stats.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>
            </tr>
            <tr>
                <td>Total Duration</td>
                <td>$($Stats.Duration.ToString('hh\:mm\:ss'))</td>
            </tr>
            <tr>
                <td>Skill Calls</td>
                <td class="info">$($Stats.SkillCalls)</td>
            </tr>
            <tr>
                <td>FL Uploads</td>
                <td class="info">$($Stats.FLUploads)</td>
            </tr>
            <tr>
                <td>Compliance Checks</td>
                <td class="info">$($Stats.ComplianceChecks)</td>
            </tr>
            <tr>
                <td>Errors</td>
                <td class="error">$($Stats.Errors)</td>
            </tr>
            <tr>
                <td>Success Rate</td>
                <td class="success">$($Stats.SuccessRate)%</td>
            </tr>
        </table>
"@

    # Add latency statistics
    $skillLatencyStats = Get-LatencyStats -Latencies $Stats.SkillCallLatencies
    $flLatencyStats = Get-LatencyStats -Latencies $Stats.FLUploadLatencies
    
    if ($skillLatencyStats) {
        $html += @"
        <h2>Skill Call Latency Statistics</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value (ms)</th>
            </tr>
            <tr>
                <td>Average</td>
                <td>$($skillLatencyStats.Average)</td>
            </tr>
            <tr>
                <td>Minimum</td>
                <td>$($skillLatencyStats.Min)</td>
            </tr>
            <tr>
                <td>Maximum</td>
                <td>$($skillLatencyStats.Max)</td>
            </tr>
            <tr>
                <td>Median</td>
                <td>$($skillLatencyStats.Median)</td>
            </tr>
            <tr>
                <td>P95</td>
                <td>$($skillLatencyStats.P95)</td>
            </tr>
            <tr>
                <td>P99</td>
                <td>$($skillLatencyStats.P99)</td>
            </tr>
            <tr>
                <td>Total Calls</td>
                <td>$($skillLatencyStats.Count)</td>
            </tr>
        </table>
"@
    }
    
    if ($flLatencyStats) {
        $html += @"
        <h2>FL Upload Latency Statistics</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value (ms)</th>
            </tr>
            <tr>
                <td>Average</td>
                <td>$($flLatencyStats.Average)</td>
            </tr>
            <tr>
                <td>Minimum</td>
                <td>$($flLatencyStats.Min)</td>
            </tr>
            <tr>
                <td>Maximum</td>
                <td>$($flLatencyStats.Max)</td>
            </tr>
            <tr>
                <td>Median</td>
                <td>$($flLatencyStats.Median)</td>
            </tr>
            <tr>
                <td>P95</td>
                <td>$($flLatencyStats.P95)</td>
            </tr>
            <tr>
                <td>P99</td>
                <td>$($flLatencyStats.P99)</td>
            </tr>
            <tr>
                <td>Total Uploads</td>
                <td>$($flLatencyStats.Count)</td>
            </tr>
        </table>
"@
    }
    
    # Add compliance checks by region
    if ($Stats.ComplianceChecksByRegion.Count -gt 0) {
        $html += @"
        <h2>Compliance Checks by Region</h2>
        <table>
            <tr>
                <th>Region</th>
                <th>Checks</th>
            </tr>
"@
        foreach ($region in $Stats.ComplianceChecksByRegion.Keys) {
            $html += @"
            <tr>
                <td>$region</td>
                <td>$($Stats.ComplianceChecksByRegion[$region])</td>
            </tr>
"@
        }
        $html += @"
        </table>
"@
    }
    
    # Add error log
    if ($Stats.ErrorLog.Count -gt 0) {
        $html += @"
        <h2>Error Log</h2>
        <div class="error-log">
"@
        foreach ($error in $Stats.ErrorLog) {
            $html += @"
            <div class="log-entry error-log">$error</div>
"@
        }
        $html += @"
        </div>
"@
    }
    
    $html += @"
        <h2>Test Conclusion</h2>
        <p>
"@
    
    if ($Stats.SuccessRate -ge 99) {
        $html += @"
            <span class="success">Excellent:</span> The test completed with a success rate of $($Stats.SuccessRate)%. 
            The system demonstrated excellent stability over the 24-hour period.
"@
    } elseif ($Stats.SuccessRate -ge 95) {
        $html += @"
            <span class="success">Good:</span> The test completed with a success rate of $($Stats.SuccessRate)%. 
            The system demonstrated good stability over the 24-hour period.
"@
    } elseif ($Stats.SuccessRate -ge 90) {
        $html += @"
            <span class="warning">Fair:</span> The test completed with a success rate of $($Stats.SuccessRate)%. 
            The system demonstrated fair stability over the 24-hour period. Some issues were encountered.
"@
    } else {
        $html += @"
            <span class="error">Poor:</span> The test completed with a success rate of $($Stats.SuccessRate)%. 
            The system demonstrated poor stability over the 24-hour period. Multiple issues were encountered.
"@
    }
    
    $html += @"
        </p>
        
        <p class="timestamp">Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p class="timestamp">Log file: $LogFile</p>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputFile -Encoding UTF8
}

# Main execution
$latestLogFile = Get-LatestLogFile

if ($null -eq $latestLogFile) {
    Write-Host "No log files found in $LogDir" -ForegroundColor Red
    exit 1
}

Write-Host "Processing log file: $($latestLogFile.FullName)" -ForegroundColor Green

$stats = Get-TestStatistics -LogFile $latestLogFile.FullName

if ($null -eq $stats) {
    Write-Host "Failed to parse log file" -ForegroundColor Red
    exit 1
}

Write-Host "Generating HTML report..." -ForegroundColor Green

$reportFile = "$OutputDir\stability_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
Generate-HTMLReport -Stats $stats -LogFile $latestLogFile.FullName -OutputFile $reportFile

Write-Host "Report generated: $reportFile" -ForegroundColor Green
Write-Host ""
Write-Host "Test Statistics:" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host "Duration: $($Stats.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host "Total Iterations: $($Stats.TotalIterations)" -ForegroundColor White
Write-Host "Skill Calls: $($Stats.SkillCalls)" -ForegroundColor White
Write-Host "FL Uploads: $($Stats.FLUploads)" -ForegroundColor White
Write-Host "Compliance Checks: $($Stats.ComplianceChecks)" -ForegroundColor White
Write-Host "Errors: $($Stats.Errors)" -ForegroundColor White
Write-Host "Success Rate: $($Stats.SuccessRate)%" -ForegroundColor White
Write-Host "Operations per Hour: $([math]::Round($Stats.OperationsPerHour, 2))" -ForegroundColor White
Write-Host "----------------------------------------" -ForegroundColor Gray