@echo off
setlocal
cd /d "%~dp0"

echo Starting PDF Auto Printer...

:: Set Python command
set PYTHON_CMD=python
%PYTHON_CMD% --version >nul 2>&1
if %errorlevel% neq 0 (
    set PYTHON_CMD=py
    %PYTHON_CMD% --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Python not found. Please run install_all.bat first.
        pause
        exit /b
    )
)

:: Run the script
%PYTHON_CMD% auto_printer.py
pause
