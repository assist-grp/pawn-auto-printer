@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo PDF Auto Printer Setup
echo ==========================================
echo.
echo Checking for administrator rights...

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    echo Please right-click the file and select "Run as administrator".
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo Admin rights: OK
echo.

:: ==========================================
:: Auto-Relocation to C:\pawn-auto-printer
:: ==========================================
set "INSTALL_DIR=%SystemDrive%\pawn-auto-printer"

:: Remove trailing backslash if present (for comparison)
set "CURRENT_DIR=%CD%"
if "%CURRENT_DIR:~-1%"=="\" set "CURRENT_DIR=%CURRENT_DIR:~0,-1%"

if /i "%CURRENT_DIR%" neq "%INSTALL_DIR%" (
    echo ==========================================
    echo Auto-Relocation to Install Directory
    echo ==========================================
    echo Installing to C drive root (%INSTALL_DIR%) for stability.
    echo.
    
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
    
    echo Copying files...
    xcopy /Y /E /I "*.*" "%INSTALL_DIR%\" >nul
    
    echo.
    echo Copy complete! Continuing installation in new location...
    timeout /t 2 >nul
    
    :: Launch the installer in the new location and exit this one
    start "" /d "%INSTALL_DIR%" "%INSTALL_DIR%\install_all.bat"
    exit /b
)

echo Current Directory: "%cd%" (Install Location)
echo.

echo ==========================================
echo Step 0: Unblock Files
echo ==========================================
echo Unblocking files to prevent security warnings...
powershell -Command "Get-ChildItem -Recurse | Unblock-File"
echo Unblock: OK
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

echo winget: OK
echo.

echo ==========================================
echo Step 1: Install Python
echo ==========================================
winget install -e --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
echo Python Setup Complete (Exit Code: %errorlevel%)
echo.

echo ==========================================
echo Step 2: Install SumatraPDF
echo ==========================================
winget install -e --id SumatraPDF.SumatraPDF --source winget --accept-package-agreements --accept-source-agreements
echo SumatraPDF Setup Complete (Exit Code: %errorlevel%)
echo.

echo ==========================================
echo Step 3: Install Libraries (watchdog etc.)
echo ==========================================
python -m pip install watchdog pystray Pillow pywin32
echo Library Setup Complete.
echo.

echo ==========================================
echo Step 4: Configure Auto-Start
echo ==========================================
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\PDFAutoPrinter.lnk');$s.TargetPath='%~dp0start_hidden.vbs';$s.WorkingDirectory='%~dp0';$s.Save()"
if %errorlevel% equ 0 (
    echo Startup shortcut created successfully.
) else (
    echo [WARNING] Failed to create startup shortcut.
)
echo.

echo ==========================================
echo Setup Complete!
echo ==========================================
echo.
echo [IMPORTANT] Please RESTART your computer.
echo After restart, the application will start automatically.
echo.
echo Opening installation folder...
start "" "%INSTALL_DIR%"
echo.
echo Press any key to exit...
pause >nul
