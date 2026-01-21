@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ==========================================
echo PDF Auto Printer Setup
echo ==========================================
echo.
echo 管理者権限をチェックしています...

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] このスクリプトは「管理者として実行」する必要があります。
    echo ファイルを右クリックして「管理者として実行」を選んでください。
    echo.
    echo 何かキーを押すと終了します...
    pause >nul
    exit /b 1
)

echo 管理者権限: OK
echo 実行ディレクトリ: "%cd%"
echo.

echo ==========================================
echo Step 0: ファイルのブロック解除
echo ==========================================
echo これにより、実行時のセキュリティ警告を回避します。
powershell -Command "Get-ChildItem -Recurse | Unblock-File"
echo ブロック解除: OK
echo.

:: Check if winget exists
echo wingetの状態を確認しています...
where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] wingetが見つかりません。
    echo Microsoft Storeから「アプリ インストーラー」を更新してください。
    echo.
    pause
    exit /b 1
)

echo winget: OK
echo.

echo ==========================================
echo Step 1: Pythonのインストール
echo ==========================================
winget install -e --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
echo Pythonのセットアップが完了しました (完了コード: %errorlevel%)
echo.

echo ==========================================
echo Step 2: SumatraPDFのインストール
echo ==========================================
winget install -e --id SumatraPDF.SumatraPDF --source winget --accept-package-agreements --accept-source-agreements
echo SumatraPDFのセットアップが完了しました (完了コード: %errorlevel%)
echo.

echo ==========================================
echo Step 3: ライブラリ (watchdog等) のインストール
echo ==========================================
python -m pip install watchdog pystray Pillow pywin32
echo ライブラリのセットアップが完了しました。
echo.

echo ==========================================
echo Step 4: 自動起動の設定
echo ==========================================
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\PDFAutoPrinter.lnk');$s.TargetPath='%~dp0start_hidden.vbs';$s.WorkingDirectory='%~dp0';$s.Save()"
if %errorlevel% equ 0 (
    echo 自動起動のショートカット作成に成功しました。
) else (
    echo [WARNING] 自動起動の設定に失敗しました。
)
echo.

echo ==========================================
echo セットアップ完了！
echo ==========================================
echo.
echo 【重要】パソコンを再起動してください。
echo 再起動後、アプリが自動的に動き始めます。
echo.
echo 何かキーを押すとこの画面を閉じます...
pause >nul
