@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo Checking if Auto Printer is Running
echo ==========================================
echo.

echo Looking for python.exe processes...
tasklist /FI "IMAGENAME eq python.exe" 2>NUL | find /I "python.exe" >NUL
if %errorlevel% equ 0 goto FOUND_PYTHON

tasklist /FI "IMAGENAME eq pythonw.exe" 2>NUL | find /I "pythonw.exe" >NUL
if %errorlevel% equ 0 goto FOUND_PYTHONW

goto NOT_RUNNING

:FOUND_PYTHON
echo.
echo [OK] Python is running.
goto CHECK_LOGS

:FOUND_PYTHONW
echo.
echo [OK] Pythonw is running (Hidden mode).
goto CHECK_LOGS

:NOT_RUNNING
echo [ERROR] Python is NOT running.
goto CHECK_LOGS

:CHECK_LOGS
echo.
echo ==========================================
echo Log File Check
echo ==========================================

if not exist "startup_error.txt" goto CHECK_DEBUG
echo.
echo [CRITICAL] STARTUP ERROR FOUND (startup_error.txt):
echo ---------------------------------------------------
type startup_error.txt
echo ---------------------------------------------------

:CHECK_DEBUG
if not exist "startup_debug.txt" goto CHECK_APP
echo.
echo [INFO] Startup Script Debug Log (startup_debug.txt):
echo ---------------------------------------------------
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
