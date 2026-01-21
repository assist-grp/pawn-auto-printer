@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

color 0F
cls
echo ==========================================
echo    PDF Auto Printer - Startup
echo ==========================================
echo.

:: Set Python command
set PYTHON_CMD=

:: 1. Check if python is in PATH
python --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python"
    goto PYTHON_FOUND
)

:: 2. Check if py is in PATH
py --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=py"
    goto PYTHON_FOUND
)

:: 3. Custom Search in User Local Programs (Standard Winget location)
for /d %%p in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
    if exist "%%p\python.exe" (
        "%%p\python.exe" --version >nul 2>&1
        if !errorlevel! equ 0 (
            set "PYTHON_CMD=%%p\python.exe"
            goto PYTHON_FOUND
        )
    )
)

:: 4. Custom Search in WindowsApps (Microsoft Store Location)
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

:: 5. Custom Search in Program Files (Standard Installer location)
for /d %%p in ("%ProgramFiles%\Python3*") do (
    if exist "%%p\python.exe" (
        "%%p\python.exe" --version >nul 2>&1
        if !errorlevel! equ 0 (
            set "PYTHON_CMD=%%p\python.exe"
            goto PYTHON_FOUND
        )
    )
)

:: 6. Custom Search in Program Files (x86)
for /d %%p in ("%ProgramFiles(x86)%\Python3*") do (
    if exist "%%p\python.exe" (
        "%%p\python.exe" --version >nul 2>&1
        if !errorlevel! equ 0 (
            set "PYTHON_CMD=%%p\python.exe"
            goto PYTHON_FOUND
        )
    )
)

:: Python not found
echo [ERROR] Python not found!
echo.
echo Please install Python 3.9+ from:
echo   https://www.python.org/
echo.
echo Or run:
echo   install_all.bat
echo.
pause
exit /b 1

:PYTHON_FOUND
echo [✓] Python found: !PYTHON_CMD!
echo.

:: Verify config.json exists
if not exist "config.json" (
    echo [⚠] config.json not found - creating default...
    python -c "import json; json.dump({'watch_directory': '', 'sumatra_path': '', 'log_file': 'printer_log.txt', 'auto_delete': True}, open('config.json', 'w'))" >nul 2>&1
    if %errorlevel% equ 0 (
        echo [✓] config.json created
    ) else (
        echo [ERROR] Failed to create config.json
        pause
        exit /b 1
    )
)

echo [✓] Configuration loaded from config.json
echo.

:: Check for startup_error.txt from previous run
if exist "startup_error.txt" (
    echo [⚠] Previous error detected:
    type startup_error.txt
    echo.
    echo Please fix the issue and try again.
    pause
    exit /b 1
)

echo Starting application...
echo.
echo ==========================================
echo Application running - Press Ctrl+C to stop
echo ==========================================
echo.

:: Run the application
"%PYTHON_CMD%" auto_printer.py

echo.
echo Application closed.
pause
