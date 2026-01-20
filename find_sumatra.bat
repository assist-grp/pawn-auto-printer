@echo off
echo Searching for SumatraPDF.exe on your system...
echo This may take a moment...
echo.

for %%d in (C D E) do (
    if exist %%d:\ (
        echo Searching drive %%d:\...
        dir /s /b "%%d:\SumatraPDF.exe" 2>nul
    )
)

echo.
echo Search complete.
echo.
echo If SumatraPDF.exe was found above, copy the full path
echo and we will update the config.json file.
echo.
pause
