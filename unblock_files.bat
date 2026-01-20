@echo off
setlocal
cd /d %~dp0

echo ==========================================
echo Unblocking all files in this folder...
echo ==========================================
echo.

powershell -Command "Get-ChildItem -Recurse | Unblock-File"

if %errorlevel% equ 0 (
    echo [SUCCESS] All files have been unblocked.
    echo Security warnings should no longer appear for these files.
) else (
    echo [ERROR] Failed to unblock files.
    echo You may need to manually unblock files via Properties.
)

echo.
pause
