@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ==========================================
echo  SumatraPDF Location Finder
echo ==========================================
echo.

echo Searching for SumatraPDF.exe...
echo.

set FOUND=0

:: Check common locations
set "LOCATIONS[0]=C:\Program Files\SumatraPDF\SumatraPDF.exe"
set "LOCATIONS[1]=C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe"
set "LOCATIONS[2]=%LOCALAPPDATA%\SumatraPDF\SumatraPDF.exe"
set "LOCATIONS[3]=%LOCALAPPDATA%\Microsoft\WindowsApps\SumatraPDF.exe"
set "LOCATIONS[4]=%LOCALAPPDATA%\Programs\SumatraPDF\SumatraPDF.exe"

for /L %%i in (0,1,4) do (
    if exist "!LOCATIONS[%%i]!" (
        echo ✓ FOUND: !LOCATIONS[%%i]!
        set FOUND=1
    ) else (
        echo ✗ Not found: !LOCATIONS[%%i]!
    )
)

echo.

if %FOUND%==0 (
    echo ==========================================
    echo ✗ SumatraPDF NOT found in common locations
    echo ==========================================
    echo.
    echo Searching entire system (this may take a minute)...
    where /R C:\ SumatraPDF.exe 2>nul
    echo.
    echo If nothing appears above, please install:
    echo https://www.sumatrapdfreader.org/
) else (
    echo ==========================================
    echo ✓ SumatraPDF found!
    echo ==========================================
)

echo.
pause
