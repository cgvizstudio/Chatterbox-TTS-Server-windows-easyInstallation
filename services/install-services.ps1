# Windows Service Installation Script for Chatterbox TTS and WhisperX
# This script installs both servers as Windows services using NSSM
# Run as Administrator

param(
    [switch]$Uninstall,
    [switch]$ChatterboxOnly,
    [switch]$WhisperXOnly
)

$ErrorActionPreference = "Continue"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$NssmPath = Join-Path $ScriptDir "nssm.exe"
$NssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
$NssmZip = Join-Path $ScriptDir "nssm.zip"
$ConfigPath = Join-Path $RootDir "config.yaml"

# Service definitions
$Services = @(
    @{
        Name = "ChatterboxTTS"
        DisplayName = "Chatterbox TTS Server"
        Description = "Text-to-Speech server using Chatterbox AI model"
        VenvPath = Join-Path $RootDir "venv"
        ScriptPath = Join-Path $RootDir "server.py"
        WorkingDir = $RootDir
        Port = 8004
    },
    @{
        Name = "WhisperXServer"
        DisplayName = "WhisperX Transcription Server"
        Description = "Audio transcription server using WhisperX"
        VenvPath = Join-Path $RootDir "whisperx-server\venv"
        ScriptPath = Join-Path $RootDir "whisperx-server\Server.py"
        WorkingDir = Join-Path $RootDir "whisperx-server"
        Port = 8005
    }
)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-ServiceModeConfig {
    # Disable auto_open_browser for service mode
    if (Test-Path $ConfigPath) {
        $configContent = Get-Content $ConfigPath -Raw
        if ($configContent -match "auto_open_browser:\s*true") {
            $configContent = $configContent -replace "auto_open_browser:\s*true", "auto_open_browser: false"
            Set-Content -Path $ConfigPath -Value $configContent -NoNewline
            Write-Host "[OK] Disabled auto_open_browser for service mode" -ForegroundColor Green
        } elseif ($configContent -notmatch "auto_open_browser:") {
            # Add the setting if it doesn't exist
            $configContent = $configContent -replace "(server:\s*\r?\n\s+host:)", "server:`n  auto_open_browser: false`n  host:"
            Set-Content -Path $ConfigPath -Value $configContent -NoNewline
            Write-Host "[OK] Added auto_open_browser: false for service mode" -ForegroundColor Green
        } else {
            Write-Host "[OK] auto_open_browser already set to false" -ForegroundColor Green
        }
    }
}

function Remove-StartupShortcuts {
    # Remove old startup shortcuts since we're using services now
    $StartupFolder = [Environment]::GetFolderPath('Startup')
    $ShortcutsToRemove = @(
        "Chatterbox*.lnk",
        "chatterbox*.lnk",
        "WhisperX*.lnk",
        "whisperx*.lnk",
        "*TTS*.lnk"
    )

    $RemovedCount = 0
    foreach ($pattern in $ShortcutsToRemove) {
        $shortcuts = Get-ChildItem -Path $StartupFolder -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($shortcut in $shortcuts) {
            try {
                Remove-Item $shortcut.FullName -Force
                Write-Host "[INFO] Removed startup shortcut: $($shortcut.Name)" -ForegroundColor Yellow
                $RemovedCount++
            } catch {
                Write-Host "[WARNING] Could not remove: $($shortcut.Name)" -ForegroundColor Yellow
            }
        }
    }

    if ($RemovedCount -gt 0) {
        Write-Host "[OK] Removed $RemovedCount startup shortcut(s) - services will handle startup now" -ForegroundColor Green
    }
}

function Get-NSSM {
    if (Test-Path $NssmPath) {
        Write-Host "[OK] NSSM already present" -ForegroundColor Green
        return $true
    }

    Write-Host "[INFO] Downloading NSSM..." -ForegroundColor Cyan
    try {
        # Download NSSM
        Invoke-WebRequest -Uri $NssmUrl -OutFile $NssmZip -UseBasicParsing

        # Extract
        $ExtractPath = Join-Path $ScriptDir "nssm-temp"
        Expand-Archive -Path $NssmZip -DestinationPath $ExtractPath -Force

        # Find and copy the 64-bit executable
        $NssmExe = Get-ChildItem -Path $ExtractPath -Recurse -Filter "nssm.exe" |
                   Where-Object { $_.Directory.Name -eq "win64" } |
                   Select-Object -First 1

        if ($NssmExe) {
            Copy-Item $NssmExe.FullName $NssmPath
            Write-Host "[OK] NSSM downloaded and extracted" -ForegroundColor Green
        } else {
            throw "Could not find nssm.exe in downloaded archive"
        }

        # Cleanup
        Remove-Item $NssmZip -Force -ErrorAction SilentlyContinue
        Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to download NSSM: $_" -ForegroundColor Red
        Write-Host "[INFO] Please download NSSM manually from https://nssm.cc/download" -ForegroundColor Yellow
        Write-Host "[INFO] Place nssm.exe in: $ScriptDir" -ForegroundColor Yellow
        return $false
    }
}

function Install-Service {
    param($ServiceConfig)

    $ServiceName = $ServiceConfig.Name
    $PythonExe = Join-Path $ServiceConfig.VenvPath "Scripts\python.exe"

    # Check if venv exists
    if (-not (Test-Path $PythonExe)) {
        Write-Host "[ERROR] Python venv not found: $PythonExe" -ForegroundColor Red
        Write-Host "[INFO] Please run setup.bat first to create the virtual environment" -ForegroundColor Yellow
        return $false
    }

    # Check if script exists
    if (-not (Test-Path $ServiceConfig.ScriptPath)) {
        Write-Host "[ERROR] Server script not found: $($ServiceConfig.ScriptPath)" -ForegroundColor Red
        return $false
    }

    # Check if service already exists
    $ExistingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($ExistingService) {
        Write-Host "[INFO] Service '$ServiceName' already exists. Removing first..." -ForegroundColor Yellow
        $null = & $NssmPath stop $ServiceName 2>&1
        $null = & $NssmPath remove $ServiceName confirm 2>&1
        Start-Sleep -Seconds 2
    }

    Write-Host "[INFO] Installing service: $($ServiceConfig.DisplayName)" -ForegroundColor Cyan

    # Install the service
    & $NssmPath install $ServiceName $PythonExe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to install service" -ForegroundColor Red
        return $false
    }

    # Configure the service
    & $NssmPath set $ServiceName AppParameters "`"$($ServiceConfig.ScriptPath)`""
    & $NssmPath set $ServiceName AppDirectory $ServiceConfig.WorkingDir
    & $NssmPath set $ServiceName DisplayName $ServiceConfig.DisplayName
    & $NssmPath set $ServiceName Description $ServiceConfig.Description
    & $NssmPath set $ServiceName Start SERVICE_AUTO_START
    & $NssmPath set $ServiceName ObjectName LocalSystem

    # Configure stdout/stderr logging
    $LogDir = Join-Path $RootDir "logs"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $StdoutLog = Join-Path $LogDir "$ServiceName-stdout.log"
    $StderrLog = Join-Path $LogDir "$ServiceName-stderr.log"

    & $NssmPath set $ServiceName AppStdout $StdoutLog
    & $NssmPath set $ServiceName AppStderr $StderrLog
    & $NssmPath set $ServiceName AppStdoutCreationDisposition 4
    & $NssmPath set $ServiceName AppStderrCreationDisposition 4
    & $NssmPath set $ServiceName AppRotateFiles 1
    & $NssmPath set $ServiceName AppRotateBytes 10485760

    # Set restart behavior on failure
    & $NssmPath set $ServiceName AppExit Default Restart
    & $NssmPath set $ServiceName AppRestartDelay 5000

    Write-Host "[OK] Service '$ServiceName' installed successfully" -ForegroundColor Green
    return $true
}

function Uninstall-Service {
    param($ServiceConfig)

    $ServiceName = $ServiceConfig.Name

    $ExistingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $ExistingService) {
        Write-Host "[INFO] Service '$ServiceName' not found, nothing to uninstall" -ForegroundColor Yellow
        return $true
    }

    Write-Host "[INFO] Stopping and removing service: $ServiceName" -ForegroundColor Cyan

    & $NssmPath stop $ServiceName 2>$null
    Start-Sleep -Seconds 2
    & $NssmPath remove $ServiceName confirm

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Service '$ServiceName' removed successfully" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[ERROR] Failed to remove service '$ServiceName'" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Chatterbox & WhisperX Service Setup  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin rights
if (-not (Test-Admin)) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "[INFO] Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Filter services based on parameters
$SelectedServices = $Services
if ($ChatterboxOnly) {
    $SelectedServices = $Services | Where-Object { $_.Name -eq "ChatterboxTTS" }
} elseif ($WhisperXOnly) {
    $SelectedServices = $Services | Where-Object { $_.Name -eq "WhisperXServer" }
}

if ($Uninstall) {
    Write-Host "[INFO] Uninstalling services..." -ForegroundColor Yellow
    foreach ($svc in $SelectedServices) {
        Uninstall-Service -ServiceConfig $svc
    }
    Write-Host ""
    Write-Host "[DONE] Uninstallation complete" -ForegroundColor Green
    exit 0
}

# Download NSSM if needed
if (-not (Get-NSSM)) {
    exit 1
}

# Configure for service mode (disable browser auto-open)
Set-ServiceModeConfig

# Remove old startup shortcuts (shell:startup)
Remove-StartupShortcuts

Write-Host ""

# Install services
$AllSuccess = $true
foreach ($svc in $SelectedServices) {
    if (-not (Install-Service -ServiceConfig $svc)) {
        $AllSuccess = $false
    }
    Write-Host ""
}

if ($AllSuccess) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!               " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Services installed:" -ForegroundColor Cyan
    foreach ($svc in $SelectedServices) {
        Write-Host "  - $($svc.DisplayName) (port $($svc.Port))" -ForegroundColor White
    }
    Write-Host ""

    # Auto-start services
    Write-Host "Starting services..." -ForegroundColor Cyan
    foreach ($svc in $SelectedServices) {
        try {
            Start-Service -Name $svc.Name -ErrorAction Stop
            Write-Host "  [OK] $($svc.Name) started" -ForegroundColor Green
        } catch {
            Write-Host "  [WARNING] Failed to start $($svc.Name): $_" -ForegroundColor Yellow
        }
    }

    # Wait a moment for services to initialize
    Start-Sleep -Seconds 3

    # Show status
    Write-Host ""
    Write-Host "Service Status:" -ForegroundColor Cyan
    foreach ($svc in $SelectedServices) {
        $status = (Get-Service -Name $svc.Name -ErrorAction SilentlyContinue).Status
        $statusColor = if ($status -eq "Running") { "Green" } else { "Yellow" }
        Write-Host "  $($svc.Name): $status" -ForegroundColor $statusColor
    }

    Write-Host ""
    Write-Host "Endpoints:" -ForegroundColor Cyan
    Write-Host "  Chatterbox TTS: http://localhost:8004" -ForegroundColor White
    Write-Host "  WhisperX:       http://localhost:8005" -ForegroundColor White
    Write-Host ""
    Write-Host "Logs are saved to: $RootDir\logs\" -ForegroundColor Cyan
} else {
    Write-Host "[WARNING] Some services failed to install" -ForegroundColor Yellow
    exit 1
}
