@echo off
echo ==========================================
echo Installed Printers on this PC:
echo ==========================================
powershell -Command "Get-Printer | Select-Object Name | Format-Table -HideTableHeaders"
echo ==========================================
echo Please copy the EXACT name of the printer 
echo you want to use for Management Tables.
echo ==========================================
pause
