# Service Management Script for Chatterbox TTS and WhisperX
# Run as Administrator for Start/Stop/Restart

param(
    [switch]$Start,
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Status,
    [switch]$ChatterboxOnly,
    [switch]$WhisperXOnly
)

$ErrorActionPreference = "Continue"

# Get script directory for relative paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

$Services = @("ChatterboxTTS", "WhisperXServer")

# Filter based on parameters
if ($ChatterboxOnly) {
    $Services = @("ChatterboxTTS")
} elseif ($WhisperXOnly) {
    $Services = @("WhisperXServer")
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ServiceStatus {
    Write-Host ""
    Write-Host "Service Status:" -ForegroundColor Cyan
    Write-Host "---------------" -ForegroundColor Cyan

    foreach ($svcName in $Services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $statusColor = switch ($svc.Status) {
                "Running" { "Green" }
                "Stopped" { "Red" }
                "StartPending" { "Yellow" }
                "StopPending" { "Yellow" }
                default { "White" }
            }
            Write-Host "  $svcName : " -NoNewline
            Write-Host $svc.Status -ForegroundColor $statusColor
        } else {
            Write-Host "  $svcName : " -NoNewline
            Write-Host "Not Installed" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

function Start-Services {
    Write-Host ""
    Write-Host "Starting services..." -ForegroundColor Cyan

    foreach ($svcName in $Services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq "Running") {
                Write-Host "  $svcName : Already running" -ForegroundColor Yellow
            } else {
                try {
                    Start-Service -Name $svcName
                    Write-Host "  $svcName : " -NoNewline
                    Write-Host "Started" -ForegroundColor Green
                } catch {
                    Write-Host "  $svcName : " -NoNewline
                    Write-Host "Failed to start - $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  $svcName : Not installed (run install-as-service.bat first)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

function Stop-Services {
    Write-Host ""
    Write-Host "Stopping services..." -ForegroundColor Cyan

    foreach ($svcName in $Services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq "Stopped") {
                Write-Host "  $svcName : Already stopped" -ForegroundColor Yellow
            } else {
                try {
                    Stop-Service -Name $svcName -Force
                    Write-Host "  $svcName : " -NoNewline
                    Write-Host "Stopped" -ForegroundColor Green
                } catch {
                    Write-Host "  $svcName : " -NoNewline
                    Write-Host "Failed to stop - $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  $svcName : Not installed" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

function Restart-Services {
    Write-Host ""
    Write-Host "Restarting services..." -ForegroundColor Cyan

    foreach ($svcName in $Services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            try {
                Restart-Service -Name $svcName -Force
                Write-Host "  $svcName : " -NoNewline
                Write-Host "Restarted" -ForegroundColor Green
            } catch {
                Write-Host "  $svcName : " -NoNewline
                Write-Host "Failed to restart - $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  $svcName : Not installed" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "  TTS Services Manager         " -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Check for action parameter
if (-not ($Start -or $Stop -or $Restart -or $Status)) {
    # Default to showing status
    $Status = $true
}

# Admin check for start/stop/restart
if (($Start -or $Stop -or $Restart) -and -not (Test-Admin)) {
    Write-Host ""
    Write-Host "[ERROR] Start/Stop/Restart requires Administrator privileges!" -ForegroundColor Red
    Write-Host "[INFO] Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if ($Status) {
    Get-ServiceStatus
}

if ($Start) {
    Start-Services
    Get-ServiceStatus
}

if ($Stop) {
    Stop-Services
    Get-ServiceStatus
}

if ($Restart) {
    Restart-Services
    Get-ServiceStatus
}

Write-Host "Endpoints:" -ForegroundColor Cyan
Write-Host "  Chatterbox TTS: http://localhost:8004" -ForegroundColor White
Write-Host "  WhisperX:       http://localhost:8005" -ForegroundColor White
Write-Host ""
Write-Host "Logs: $RootDir\logs\" -ForegroundColor DarkGray
Write-Host ""
