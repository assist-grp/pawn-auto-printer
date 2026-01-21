@echo off
cd /d "%~dp0"

REM Start the Python script hidden in background
start /B pythonw auto_printer.py

REM Create a simple notification
echo PDF Auto Printer started in background.
timeout /t 2 >nul
