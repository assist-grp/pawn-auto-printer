@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

color 0F
cls
echo.
echo ==========================================
echo   PDF Auto Printer - Status Check
echo ==========================================
echo.

echo [1/4] Checking running processes...
echo.

:: Check for python.exe
tasklist /FI "IMAGENAME eq python.exe" 2>NUL | find /I "python.exe" >NUL
if %errorlevel% equ 0 (
    echo   ✓ python.exe is running (Interactive mode)
    set "RUNNING=YES"
    goto CHECK_PYTHONW
)

echo   ✗ python.exe NOT found

:CHECK_PYTHONW
tasklist /FI "IMAGENAME eq pythonw.exe" 2>NUL | find /I "pythonw.exe" >NUL
if %errorlevel% equ 0 (
    echo   ✓ pythonw.exe is running (Background mode)
    set "RUNNING=YES"
    goto STATUS_CHECK
)

echo   ✗ pythonw.exe NOT found

:STATUS_CHECK
if "!RUNNING!"=="YES" (
    echo.
    echo ✓ Application is RUNNING
) else (
    echo.
    echo ✗ Application is NOT RUNNING
)

echo.
echo [2/4] Checking error files...
echo.

if exist "startup_error.txt" (
    echo   ⚠ STARTUP ERROR FOUND:
    echo   -----------------------------------------------
    type startup_error.txt
    echo   -----------------------------------------------
) else (
    echo   ✓ No startup errors
)

if exist "startup_debug.txt" (
    echo.
    echo   [Debug Log]:
    type startup_debug.txt
)

echo.
echo [3/4] Checking configuration...
echo.

if exist "config.json" (
    echo   ✓ config.json found
    :: Show first few lines
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-Content config.json | Select-Object -First 3" 2^>nul') do (
        echo   %%a
    )
) else (
    echo   ✗ config.json NOT found
)

echo.
echo [4/4] Checking log file...
echo.

if exist "printer_log.txt" (
    echo   ✓ printer_log.txt found
    :: Show last 10 lines
    echo.
    echo   --- Last 10 log entries ---
    for /f "skip=999999" %%a in ('find /c /v "" ^< "printer_log.txt"') do set lines=%%a
    if !lines! GTR 10 (
        powershell -NoProfile -Command "Get-Content printer_log.txt | Select-Object -Last 10" 2>nul
    ) else (
        type printer_log.txt
    )
    echo   --- End of log ---
) else (
    echo   ✗ printer_log.txt NOT found (No activity yet)
)

echo.
echo ==========================================
echo Summary
echo ==========================================
echo.

if "!RUNNING!"=="YES" (
    echo Application Status: ✓ RUNNING
    echo Log file: printer_log.txt
    echo.
    echo To stop: stop_printer.bat
    echo To view real-time log: debug_runner.bat
) else (
    echo Application Status: ✗ NOT RUNNING
    echo.
    echo To start: run_printer.bat
    echo For debug: debug_runner.bat
    echo For help: TROUBLESHOOTING.md
)

echo.
pause
type startup_debug.txt
echo ---------------------------------------------------

:CHECK_APP
if not exist "printer_log.txt" goto NO_APP_LOG
echo.
echo [INFO] Application Log (printer_log.txt - Last 10 lines):
echo ---------------------------------------------------
powershell -Command "Get-Content printer_log.txt -Tail 10"
echo ---------------------------------------------------
goto FINISH

:NO_APP_LOG
echo.
echo [WARNING] printer_log.txt not found (App never started completely).

:FINISH
echo.
echo ==========================================
pause
