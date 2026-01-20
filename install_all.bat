@echo off
setlocal
cd /d %~dp0

echo ==========================================
echo PDF Auto Printer Setup
echo ==========================================
echo.
echo Checking administrator privileges...

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script requires administrator privileges.
    echo Please right-click this file and select "Run as administrator"
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo Administrator check: OK
echo.

:: Check if winget exists
echo Checking for winget...
where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] winget not found.
    echo Please update "App Installer" from Microsoft Store.
    echo.
    pause
    exit /b 1
)

echo winget found: OK
echo.

echo ==========================================
echo Step 1: Installing Python
echo ==========================================
winget install -e --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
echo Python installation command completed (exit code: %errorlevel%)
echo.

echo ==========================================
echo Step 2: Installing SumatraPDF
echo ==========================================
winget install -e --id SumatraPDF.SumatraPDF --source winget --accept-package-agreements --accept-source-agreements
echo SumatraPDF installation command completed (exit code: %errorlevel%)
echo.

echo ==========================================
echo Step 3: Installing Python library (watchdog)
echo ==========================================
echo Note: This may fail if Python path is not yet updated.
echo If it fails, it will be installed automatically on first run.
python -m pip install watchdog pystray Pillow pywin32
echo.

echo ==========================================
echo Step 4: Setting up auto-start
echo ==========================================
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\PDFAutoPrinter.lnk');$s.TargetPath='%~dp0start_hidden.vbs';$s.WorkingDirectory='%~dp0';$s.Save()"
if %errorlevel% equ 0 (
    echo Auto-start shortcut created successfully.
) else (
    echo [WARNING] Failed to create auto-start shortcut.
)
echo.

echo ==========================================
echo Setup Complete!
echo ==========================================
echo.
echo IMPORTANT: Please RESTART your computer now.
echo After restart, the app will start automatically.
echo.
echo If you see any errors above, please take a screenshot
echo and share it for troubleshooting.
echo.
pause
