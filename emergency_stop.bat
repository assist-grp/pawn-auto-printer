@echo off
echo ==========================================
echo EMERGENCY STOP: PDF Auto Printer
echo ==========================================
echo.
echo Stopping all related processes...
taskkill /f /im python.exe /t >nul 2>&1
taskkill /f /im pythonw.exe /t >nul 2>&1
taskkill /f /im wscript.exe >nul 2>&1

echo.
echo Removing startup shortcut...
del /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\PDFAutoPrinter.lnk" >nul 2>&1

echo.
echo Cleanup complete. Your PC should respond normally now.
echo.
pause
