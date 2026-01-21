# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator." -ForegroundColor Red
    
    # Attempt to relaunch as admin
    $process = New-Object System.Diagnostics.ProcessStartInfo "powershell"
    $process.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $process.Verb = "runas"
    # CRITICAL FIX: Set Working Directory to current script location to avoid System32
    $process.WorkingDirectory = $PSScriptRoot 
    try {
        [System.Diagnostics.Process]::Start($process)
        exit
    } catch {
        Write-Host "Failed to relaunch as admin. Please do it manually."
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

# Ensure we are in the script's directory (double check)
Set-Location -Path $PSScriptRoot

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      PDF Auto Printer Setup (PS)         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Working Directory: $PWD"
Write-Host ""

# ---------------------------------------------------------
# 1. Setup Installation Directory
# ---------------------------------------------------------
$InstallDir = "C:\pawn-auto-printer"
$SourceDir = $PSScriptRoot

# Avoid recursively copying if we are already in the target (or subdirectory)
if ($SourceDir -ne $InstallDir) {
    Write-Host "Installing to $InstallDir..." -ForegroundColor Yellow
    
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }
    
    Write-Host "Copying files from: $SourceDir"
    # Exclude self execution if possible, but Copy-Item handles simple cases
    Copy-Item -Path "$SourceDir\*" -Destination "$InstallDir" -Recurse -Force
    
    Write-Host "Files copied successfully."
    
    # Relaunch from the new location
    $NewScriptPath = Join-Path $InstallDir "install.ps1"
    
    if (Test-Path $NewScriptPath) {
        Write-Host "Relaunching from install directory..."
        $process = New-Object System.Diagnostics.ProcessStartInfo "powershell"
        $process.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$NewScriptPath`""
        $process.Verb = "runas"
        $process.WorkingDirectory = $InstallDir
        [System.Diagnostics.Process]::Start($process)
        exit
    }
}

Write-Host "Step 1: Installation location confirmed: $InstallDir"
Write-Host ""

# ---------------------------------------------------------
# 2. Unblock Files
# ---------------------------------------------------------
Write-Host "Step 2: Unblocking files in $InstallDir..." -ForegroundColor Green
# CRITICAL FIX: Explicitly target the install directory, not System32
Get-ChildItem -Path $InstallDir -Recurse | Unblock-File
Write-Host "Files unblocked."
Write-Host ""

# ---------------------------------------------------------
# 3. Check/Install Dependencies (Winget)
# ---------------------------------------------------------
Write-Host "Step 3: Checking Dependencies..." -ForegroundColor Green

function Test-Command ($command) {
    return (Get-Command $command -ErrorAction SilentlyContinue)
}

# Check Python first
if (Test-Command "python") {
    $pyVer = python --version 2>&1
    Write-Host "Python is already installed: $pyVer" -ForegroundColor Cyan
} else {
    Write-Host "Python not found. Attempting install via winget..."
    if (Test-Command "winget") {
        # Try generic Python 3 first
        winget install -e --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
             Write-Host "[WARNING] Failed to install 'Python.Python.3'. Trying 'Python.Python.3.12'..." -ForegroundColor Yellow
             winget install -e --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements
        }
    } else {
        Write-Host "[ERROR] 'winget' not found and Python is missing." -ForegroundColor Red
        Write-Host "Please install Python manually from python.org"
    }
}

# Install SumatraPDF (Always try update/install)
Write-Host "Checking SumatraPDF..."
winget install -e --id SumatraPDF.SumatraPDF --source winget --accept-package-agreements --accept-source-agreements
Write-Host "Dependencies check complete."
Write-Host ""

# ---------------------------------------------------------
# 4. Install Python Libraries
# ---------------------------------------------------------
Write-Host "Step 4: Installing Python Libraries..." -ForegroundColor Green
try {
    # Refresh env vars for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (Test-Command "python") {
        Write-Host "Running pip install..."
        python -m pip install --upgrade pip
        python -m pip install watchdog pystray Pillow pywin32
        Write-Host "Pip install complete."
    } else {
        Write-Host "[WARNING] Python command still not found. You may need to restart and run this again." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERROR] Failed to install libraries: $_" -ForegroundColor Red
}
Write-Host ""

# ---------------------------------------------------------
# 5. Configure Auto-Start
# ---------------------------------------------------------
Write-Host "Step 5: Creating Startup Shortcut..." -ForegroundColor Green
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $StartupDir = $WshShell.SpecialFolders.Item("Startup")
    $ShortcutPath = Join-Path $StartupDir "PDFAutoPrinter.lnk"
    $TargetScript = Join-Path $InstallDir "start_hidden.vbs"
    
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetScript
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Save()
    
    Write-Host "Shortcut created at: $ShortcutPath"
} catch {
    Write-Host "[ERROR] Failed to create shortcut: $_" -ForegroundColor Red
}
Write-Host ""

# ---------------------------------------------------------
# Completion
# ---------------------------------------------------------
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "           Setup Complete!                " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting the application..."
try {
    # Start the VBS script to run in background
    Start-Process "wscript.exe" -ArgumentList "`"$InstallDir\start_hidden.vbs`""
    Write-Host "Application started successfully." -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Could not auto-start. Please run manual_start.bat or reboot." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Opening installation folder..."
Invoke-Item $InstallDir
Write-Host "Press Enter to exit..."
Read-Host
