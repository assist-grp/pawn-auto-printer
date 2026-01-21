@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

color 0F
cls
echo.
echo ==========================================
echo   PDF Auto Printer - DEBUG MODE
echo ==========================================
echo.
echo This shows detailed console output for
echo troubleshooting. Press Ctrl+C to stop.
echo.
echo All output is also saved to: printer_log.txt
echo ==========================================
echo.

:: Find Python (same logic as run_printer.bat)
set PYTHON_CMD=

python --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python"
    goto PYTHON_FOUND
)

py --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=py"
    goto PYTHON_FOUND
)

for /d %%p in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
    if exist "%%p\python.exe" (
        "%%p\python.exe" --version >nul 2>&1
        if !errorlevel! equ 0 (
            set "PYTHON_CMD=%%p\python.exe"
            goto PYTHON_FOUND
        )
    )
)

if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" (
    "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" --version >nul 2>&1
    if !errorlevel! equ 0 (
        set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe"
        goto PYTHON_FOUND
    )
)

if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe" (
    "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe" --version >nul 2>&1
    if !errorlevel! equ 0 (
        set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe"
        goto PYTHON_FOUND
    )
)

for /d %%p in ("%ProgramFiles%\Python3*") do (
    if exist "%%p\python.exe" (
        "%%p\python.exe" --version >nul 2>&1
        if !errorlevel! equ 0 (
            set "PYTHON_CMD=%%p\python.exe"
            goto PYTHON_FOUND
        )
    )
)

echo [ERROR] Python not found!
pause
exit /b 1

:PYTHON_FOUND
echo [✓] Running with Python: !PYTHON_CMD!
echo.
echo ========================================== 
echo Starting auto_printer.py (Debug Mode)
echo ==========================================
echo.

"%PYTHON_CMD%" auto_printer.py

echo.
echo ==========================================
echo Debug session ended
echo ==========================================
echo.
pause
