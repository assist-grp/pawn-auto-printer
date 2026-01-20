@echo off
echo ==========================================
echo Checking if Auto Printer is Running
echo ==========================================
echo.

echo Looking for python.exe processes...
tasklist /FI "IMAGENAME eq python.exe" | find /I "python.exe"
if %errorlevel% equ 0 (
    echo.
    echo Python is running. Checking details...
    wmic process where "name='python.exe'" get commandline
) else (
    echo Python is NOT running.
    echo The auto printer app is NOT active.
)

echo.
echo ==========================================
echo Checking log file
echo ==========================================
if exist printer_log.txt (
    echo Log file found. Last 20 lines:
    echo.
    powershell -Command "Get-Content printer_log.txt -Tail 20"
) else (
    echo Log file NOT found. The app has never been started.
)

echo.
echo ==========================================
pause
