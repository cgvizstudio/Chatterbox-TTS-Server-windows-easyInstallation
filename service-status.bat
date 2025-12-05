@echo off
:: Check status of Chatterbox TTS and WhisperX Windows Services

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "services\manage-services.ps1" -Status
pause
