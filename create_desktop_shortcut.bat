@echo off
echo Creating desktop shortcut for PDF Auto Printer...

set SCRIPT_DIR=%~dp0
set SHORTCUT_PATH=%USERPROFILE%\Desktop\PDF Auto Printer.lnk

powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.TargetPath='%SCRIPT_DIR%start_hidden.vbs';$s.WorkingDirectory='%SCRIPT_DIR%';$s.IconLocation='%SCRIPT_DIR%app_icon.ico';$s.Description='PDF Auto Printer - Manual restart (auto-starts with Windows)';$s.Save()"

if exist "%SHORTCUT_PATH%" (
    echo.
    echo Success! Shortcut created on Desktop.
    echo.
    echo IMPORTANT:
    echo - The app will auto-start when Windows boots
    echo - Use this icon ONLY if you need to manually restart the app
    echo - If already running, clicking will show a notification
) else (
    echo.
    echo Failed to create shortcut.
)

echo.
pause
