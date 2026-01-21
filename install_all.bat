@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo Starting PDF Auto Printer Setup...
echo ==========================================
echo.

:: Launch the PowerShell installer
:: -NoProfile: Faster startup
:: -ExecutionPolicy Bypass: Allow script to run
:: -File: The script to run
powershell -NoProfile -ExecutionPolicy Bypass -File "install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Installation failed or was cancelled.
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Installer has finished.
echo ==========================================
pause
