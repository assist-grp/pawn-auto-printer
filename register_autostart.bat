@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo   PDF Auto Printer - Auto-Start Setup
echo ==========================================
echo.

:: Require Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Administrator privileges required.
    echo.
    echo Please right-click register_autostart.bat and select
    echo "Run as administrator".
    echo.
    pause
    exit /b 1
)

set "VBS=%~dp0start_hidden.vbs"

if not exist "%VBS%" (
    echo [ERROR] start_hidden.vbs not found in this folder:
    echo   %~dp0
    echo.
    pause
    exit /b 1
)

echo Registering scheduled task "PDFAutoPrinter"...
echo Target: %VBS%
echo.

:: Create a logon-triggered task for the current user.
:: Runs at every sign-in, in the user session (tray icon works).
schtasks /Create /TN "PDFAutoPrinter" /TR "wscript.exe \"%VBS%\"" /SC ONLOGON /RL LIMITED /F

if %errorlevel% equ 0 (
    echo.
    echo ==========================================
    echo   SUCCESS - Auto-start registered.
    echo ==========================================
    echo.
    echo The app will now launch automatically every time
    echo you sign in to Windows.
    echo.
    echo Starting the app now for this session...
    start "" "wscript.exe" "%VBS%"
    echo Done.
) else (
    echo.
    echo [ERROR] Failed to register the scheduled task.
    echo Please make sure you ran this as Administrator.
)

echo.
pause
