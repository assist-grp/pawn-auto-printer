@echo off
echo Creating desktop shortcut for PDF Auto Printer...

set "SCRIPT_DIR=%~dp0"

:: デスクトップの場所は決め打ちせず、Windows に問い合わせて取得する。
:: [Environment]::GetFolderPath('Desktop') は OneDrive にデスクトップが
:: 移動（リダイレクト）されている環境でも、正しい実際のパスを返す。
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $p=Join-Path $d 'PDF Auto Printer.lnk'; $w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut($p); $s.TargetPath=Join-Path '%SCRIPT_DIR%' 'start_hidden.vbs'; $s.WorkingDirectory='%SCRIPT_DIR%'; $s.IconLocation=Join-Path '%SCRIPT_DIR%' 'app_icon.ico'; $s.Description='PDF Auto Printer - Manual restart (auto-starts with Windows)'; $s.Save(); if (Test-Path $p) { Write-Host ('Created: ' + $p); exit 0 } else { exit 1 }"

if %errorlevel% equ 0 (
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
    echo Try right-clicking start_hidden.vbs and using
    echo "Send to" - "Desktop (create shortcut)" instead.
)

echo.
pause
