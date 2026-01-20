@echo off
echo ==========================================
echo Checking for Multiple Python Instances
echo ==========================================
echo.

echo All running python.exe processes:
tasklist /FI "IMAGENAME eq python.exe" /V
echo.

echo All running pythonw.exe processes (background):
tasklist /FI "IMAGENAME eq pythonw.exe" /V
echo.

echo ==========================================
echo If you see multiple instances, run stop_printer.bat
echo to stop all of them before starting again.
echo ==========================================
pause
