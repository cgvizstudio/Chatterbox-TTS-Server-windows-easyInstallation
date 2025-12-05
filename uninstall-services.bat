@echo off
:: Uninstall Chatterbox TTS and WhisperX Windows Services
:: Must be run as Administrator

echo.
echo ==========================================
echo   Uninstalling Windows Services
echo ==========================================
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Change to script directory and run PowerShell uninstaller
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "services\install-services.ps1" -Uninstall

echo.
pause
