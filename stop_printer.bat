@echo off
echo Stopping all running Python auto printer processes...
taskkill /F /IM python.exe 2>nul
taskkill /F /IM pythonw.exe 2>nul
echo.
echo All Python processes stopped.
echo Please run the app again to restart.
pause
