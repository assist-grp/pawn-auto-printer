@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo Running Installer in DEBUG Mode
echo ==========================================
echo Logs will be saved to: install_log.txt
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "install.ps1" > install_log.txt 2>&1

echo.
echo ==========================================
echo Execution Finished
echo ==========================================
echo Please check install_log.txt for any errors.
echo.
pause
