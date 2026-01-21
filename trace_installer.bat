:: This script executes commands one by one with pauses to find the error.
echo ON

echo ==========================================
echo TRACE INSTALLER START
echo ==========================================
pause

echo Setting local environment...
setlocal
pause

echo Changing directory...
cd /d "%~dp0"
echo Current dir: %cd%
pause

echo Checking for install.ps1...
if exist "install.ps1" (
    echo install.ps1 FOUND.
) else (
    echo [ERROR] install.ps1 NOT FOUND!
    pause
    exit /b
)
pause

echo Checking for PowerShell...
powershell -Version
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell not working!
    pause
    exit /b
)
pause

echo ==========================================
echo Starting PowerShell Script...
echo ==========================================
echo Note: A new window might open if Admin rights are needed.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "install.ps1"

echo.
echo ==========================================
echo Script Finished.
echo ==========================================
echo Check output above.
pause
