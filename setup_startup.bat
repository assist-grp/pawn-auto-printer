@echo off
chcp 65001 >nul
set "target=%~dp0start_hidden.vbs"
set "shortcut=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\PDFAutoPrinter.lnk"

echo Registering PDF Auto Printer for automatic startup...
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%shortcut%');$s.TargetPath='%target%';$s.WorkingDirectory='%~dp0';$s.Save()"

if exist "%shortcut%" (
    echo.
    echo Success! PDF Auto Printer will start automatically when Windows starts.
    echo The app will run in background without showing a window.
) else (
    echo.
    echo Failed to create startup shortcut.
)

echo.
pause
