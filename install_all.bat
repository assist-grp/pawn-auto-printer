@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

color 0F
cls
echo.
echo ==========================================
echo   PDF Auto Printer - Setup Installer
echo ==========================================
echo.
echo This will install all required dependencies
echo and configure the application.
echo.
echo Requirements:
echo   - Administrator privileges
echo   - Internet connection (winget)
echo   - 500MB free disk space
echo.
echo ==========================================
echo.

:: Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges!
    echo.
    echo Please right-click install_all.bat and select
    echo "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo [1/2] Starting PowerShell installation...
echo.

:: Launch the PowerShell installer
:: -NoProfile: Faster startup
:: -ExecutionPolicy Bypass: Allow script to run
:: -File: The script to run
powershell -NoProfile -ExecutionPolicy Bypass -File "install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Installation failed or was cancelled.
    echo.
    echo Please try:
    echo   1. Run verify_installation.bat to check status
    echo   2. Check printer_log.txt for error details
    echo   3. Try running install_all.bat again as Administrator
    echo.
    pause
    exit /b %errorlevel%
)

echo.
echo [2/2] Running installation verification...
echo.

:: Run verification
call verify_installation.bat
set VERIFY_RESULT=%errorlevel%

if %VERIFY_RESULT% equ 0 (
    echo.
    echo ==========================================
    echo    Installation SUCCESSFUL!
    echo ==========================================
    echo.
    echo Next steps:
    echo   1. Configure config.json with your settings
    echo   2. Run run_printer.bat to start
    echo   3. Or run start_background.bat for background mode
    echo.
    echo For help, see:
    echo   - INSTALL_JP.md (Japanese)
    echo   - INSTALL_EN.md (English)
    echo.
) else (
    echo.
    echo ==========================================
    echo    Installation completed with issues
    echo ==========================================
    echo.
    echo Please check verify_installation.bat output
    echo and install any missing components manually.
    echo.
)

pause
