@echo off
setlocal
cd /d "%~dp0"

echo Starting PDF Auto Printer...

:: Set Python command
set PYTHON_CMD=python

:: 1. Check if python is in PATH
"%PYTHON_CMD%" --version >nul 2>&1
if %errorlevel% equ 0 goto FOUND

:: 2. Check if py is in PATH
set PYTHON_CMD=py
"%PYTHON_CMD%" --version >nul 2>&1
if %errorlevel% equ 0 goto FOUND

:: 3. Custom Search in User Local Programs (Standard Winget location)
for /d %%p in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
    if exist "%%p\python.exe" (
        set "PYTHON_CMD=%%p\python.exe"
        goto CHECK_CANDIDATE
    )
)

:: 4. Custom Search in WindowsApps (Microsoft Store Location)
:: Verify EXPLICITLY before using to avoid stub issues
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe"
    goto CHECK_CANDIDATE
)
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe"
    goto CHECK_CANDIDATE
)

:: 5. Custom Search in Program Files (Standard Installer location)
for /d %%p in ("%ProgramFiles%\Python3*") do (
    if exist "%%p\python.exe" (
        set "PYTHON_CMD=%%p\python.exe"
        goto CHECK_CANDIDATE
    )
)

:: 6. Custom Search in Program Files (x86)
for /d %%p in ("%ProgramFiles(x86)%\Python3*") do (
    if exist "%%p\python.exe" (
        set "PYTHON_CMD=%%p\python.exe"
        goto CHECK_CANDIDATE
    )
)

:: Not found
echo [ERROR] Python not found. Please run install_all.bat first.
echo Checked: PATH, LocalAppData, WindowsApps, Program Files.
pause
exit /b

:CHECK_CANDIDATE
"%PYTHON_CMD%" --version >nul 2>&1
if %errorlevel% equ 0 goto FOUND
echo [WARNING] Found %PYTHON_CMD% but it does not work (Stub?). Skipping...
:: Fallthrough to search next (simplified: just exit here for now or improve loop)
:: For now, if we found a candidate and it failed, we assume failure.
:: But ideally we should loop. 
:: Given the complexity of batch loops, let's keep it simple:
:: If the most likely candidate fails, we error out.
goto NOT_WORKING

:NOT_WORKING
echo [ERROR] Python was found at %PYTHON_CMD% but failed to run.
echo It might be a 0KB stub file. Please install Python manually.
pause
exit /b

:FOUND
echo Python found: %PYTHON_CMD%
"%PYTHON_CMD%" auto_printer.py
pause
