@echo off
setlocal
cd /d %~dp0

echo ==========================================
echo Manual Print Test
echo ==========================================
echo.
echo This will manually trigger a print test
echo without relying on file monitoring.
echo.

set /p filename="Enter PDF filename in Downloads folder (e.g., 買取同意書.pdf): "

if "%filename%"=="" (
    echo No filename entered.
    pause
    exit /b
)

set filepath="%USERPROFILE%\Downloads\%filename%"

if not exist %filepath% (
    echo ERROR: File not found: %filepath%
    pause
    exit /b
)

echo.
echo Testing with file: %filepath%
echo.

python -c "import sys; sys.path.insert(0, '.'); from auto_printer import PDFHandler; handler = PDFHandler(); handler.process_file(r'%USERPROFILE%\Downloads\%filename%', '%filename%')"

echo.
echo Test complete. Check if printing started.
pause
