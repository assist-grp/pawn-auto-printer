@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo Checking if Auto Printer is Running
echo ==========================================
echo.

echo Looking for python.exe processes...
tasklist /FI "IMAGENAME eq python.exe" | find /I "python.exe"
if %errorlevel% equ 0 (
    echo.
    echo [OK] Python is running.
) else (
    tasklist /FI "IMAGENAME eq pythonw.exe" | find /I "pythonw.exe"
    if %errorlevel% equ 0 (
        echo.
        echo [OK] Pythonw is running (Hidden mode).
    ) else (
        echo [ERROR] Python is NOT running.
    )
)

echo.
echo ==========================================
echo Log File Check
echo ==========================================

if exist "startup_error.txt" (
    echo.
    echo [CRITICAL] STARTUP ERROR FOUND (startup_error.txt):
    echo ---------------------------------------------------
    type startup_error.txt
    echo ---------------------------------------------------
)

if exist "startup_debug.txt" (
    echo.
    echo [INFO] Startup Script Debug Log (startup_debug.txt):
    echo ---------------------------------------------------
    type startup_debug.txt
    echo ---------------------------------------------------
)

if exist "printer_log.txt" (
    echo.
    echo [INFO] Application Log (printer_log.txt - Last 10 lines):
    echo ---------------------------------------------------
    powershell -Command "Get-Content printer_log.txt -Tail 10"
    echo ---------------------------------------------------
) else (
    echo.
    echo [WARNING] printer_log.txt not found (App never started completely).
)

echo.
echo ==========================================
pause
