@echo off
setlocal
cd /d "%~dp0"

echo Starting PDF Auto Printer...

:: Set Python command
set PYTHON_CMD=python

:: 1. Check if python is in PATH
%PYTHON_CMD% --version >nul 2>&1
if %errorlevel% equ 0 goto FOUND

:: 2. Check if py is in PATH
set PYTHON_CMD=py
%PYTHON_CMD% --version >nul 2>&1
if %errorlevel% equ 0 goto FOUND

:: 3. Custom Search in User Local Programs (Standard Winget location)
for /d %%p in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
    if exist "%%p\python.exe" (
        set "PYTHON_CMD=%%p\python.exe"
        goto FOUND
    )
)

:: 4. Custom Search in WindowsApps (Microsoft Store Location)
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe"
    goto FOUND
)
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe"
    goto FOUND
)

:: 5. Custom Search in Program Files (Standard Installer location)
for /d %%p in ("%ProgramFiles%\Python3*") do (
    if exist "%%p\python.exe" (
        set "PYTHON_CMD=%%p\python.exe"
        goto FOUND
    )
)

:: 6. Custom Search in Program Files (x86)
for /d %%p in ("%ProgramFiles(x86)%\Python3*") do (
    if exist "%%p\python.exe" (
        set "PYTHON_CMD=%%p\python.exe"
        goto FOUND
    )
)

:: Not found
echo [ERROR] Python not found. Please run install_all.bat first.
echo Checked: PATH, LocalAppData, WindowsApps, Program Files.
pause
exit /b

:FOUND
echo Python found: %PYTHON_CMD%
"%PYTHON_CMD%" auto_printer.py
pause
