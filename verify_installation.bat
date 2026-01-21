@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ==========================================
echo  PDF Auto Printer - Installation Verify
echo ==========================================
echo.

setlocal
set PYTHON_CMD=

:: Find Python
echo [1/5] Checking Python installation...
python --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do set "PYTHON_VER=%%i"
    echo   ✓ Python found: !PYTHON_VER!
    set "PYTHON_CMD=python"
    goto PYTHON_FOUND
)

py --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('py --version 2^>^&1') do set "PYTHON_VER=%%i"
    echo   ✓ Python launcher found: !PYTHON_VER!
    set "PYTHON_CMD=py"
    goto PYTHON_FOUND
)

if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" (
    for /f "tokens=*" %%i in ('"%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" --version 2^>^&1') do set "PYTHON_VER=%%i"
    echo   ✓ Python found in WindowsApps: !PYTHON_VER!
    set "PYTHON_CMD=%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe"
    goto PYTHON_FOUND
)

echo   ✗ Python NOT found!
echo     Please install Python from https://www.python.org/
echo     Or run install_all.bat first
goto FAILED

:PYTHON_FOUND
echo.

:: Check dependencies
echo [2/5] Checking Python packages...
"%PYTHON_CMD%" -c "import watchdog" >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ watchdog installed
) else (
    echo   ✗ watchdog NOT found
    goto DEPS_MISSING
)

"%PYTHON_CMD%" -c "import pystray" >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ pystray installed
) else (
    echo   ✗ pystray NOT found
    goto DEPS_MISSING
)

"%PYTHON_CMD%" -c "import PIL" >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ Pillow installed
) else (
    echo   ✗ Pillow NOT found
    goto DEPS_MISSING
)

"%PYTHON_CMD%" -c "import win32print" >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ pywin32 installed
) else (
    echo   ✗ pywin32 NOT found
    goto DEPS_MISSING
)

goto DEPS_OK

:DEPS_MISSING
echo.
echo [ERROR] Missing Python packages!
echo Run: %PYTHON_CMD% -m pip install watchdog pystray Pillow pywin32
pause
exit /b 1

:DEPS_OK
echo.

:: Check config.json
echo [3/5] Checking configuration...
if exist "config.json" (
    echo   ✓ config.json found
) else (
    echo   ✗ config.json NOT found - creating default...
    "%PYTHON_CMD%" -c "import json; json.dump({'watch_directory': '', 'sumatra_path': '', 'log_file': 'printer_log.txt', 'auto_delete': True}, open('config.json', 'w'))"
    echo   ✓ config.json created with defaults
)
echo.

:: Check SumatraPDF
echo [4/5] Checking SumatraPDF installation...
if exist "C:\Program Files\SumatraPDF\SumatraPDF.exe" (
    echo   ✓ SumatraPDF found at C:\Program Files\SumatraPDF\
    goto SUMATRA_OK
)
if exist "C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe" (
    echo   ✓ SumatraPDF found at C:\Program Files (x86)\SumatraPDF\
    goto SUMATRA_OK
)
echo   ⚠ SumatraPDF NOT found
echo     Install from: https://www.sumatrapdfreader.org/
echo     App will auto-detect if installed later
goto BROWSER_CHECK

:SUMATRA_OK
:BROWSER_CHECK
echo.

:: Check browsers
echo [5/5] Checking Edge/Chrome installation...
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
    echo   ✓ Microsoft Edge found
    goto BROWSER_OK
)
if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    echo   ✓ Microsoft Edge found (x86)
    goto BROWSER_OK
)
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo   ✓ Google Chrome found
    goto BROWSER_OK
)
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    echo   ✓ Google Chrome found (x86)
    goto BROWSER_OK
)
echo   ⚠ Edge/Chrome NOT found
echo     Install one of them for HTML conversion
goto CHECK_COMPLETE

:BROWSER_OK
:CHECK_COMPLETE
echo.
echo ==========================================
echo ✓ All critical dependencies verified!
echo ==========================================
echo.
echo Next: Run "run_printer.bat" to start
echo.
pause
exit /b 0

:FAILED
echo.
echo ==========================================
echo ✗ Installation verification FAILED
echo ==========================================
echo.
pause
exit /b 1
