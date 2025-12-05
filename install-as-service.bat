@echo off
:: Install Chatterbox TTS and WhisperX as Windows Services
:: Must be run as Administrator

echo.
echo ==========================================
echo   Installing as Windows Services
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

:: Change to script directory and run PowerShell installer
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "services\install-services.ps1"

echo.
pause
