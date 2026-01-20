@echo off
echo ==========================================
echo Environment Test
echo ==========================================
echo.

echo Testing winget...
where winget
if %errorlevel% equ 0 (
    echo winget: OK
    winget --version
) else (
    echo winget: NOT FOUND
)
echo.

echo Testing python...
where python
if %errorlevel% equ 0 (
    echo python: OK
    python --version
) else (
    echo python: NOT FOUND
)
echo.

echo Testing py launcher...
where py
if %errorlevel% equ 0 (
    echo py: OK
    py --version
) else (
    echo py: NOT FOUND
)
echo.

echo Testing SumatraPDF...
where SumatraPDF
if %errorlevel% equ 0 (
    echo SumatraPDF: OK
) else (
    echo SumatraPDF: NOT FOUND
)
echo.

echo ==========================================
echo Test Complete
echo ==========================================
echo Please take a screenshot of this window
echo and share it for troubleshooting.
echo.
pause
