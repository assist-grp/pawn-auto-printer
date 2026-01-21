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
# User requested IN-PLACE installation (e.g. in Downloads folder)
# We no longer copy to C:\pawn-auto-printer
$InstallDir = $PSScriptRoot
$SourceDir = $PSScriptRoot

Write-Host "Step 1: Installation location confirmed: $InstallDir"
Write-Host "       (Running in-place as requested)"
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
# 3. Check/Install Dependencies (Winget + Fallback)
# ---------------------------------------------------------
Write-Host "Step 3: Checking Dependencies..." -ForegroundColor Green

function Test-Command ($command) {
    return (Get-Command $command -ErrorAction SilentlyContinue)
}

function Install-Python-Fallback {
    Write-Host "[INFO] Attempting Direct Python Download & Install..." -ForegroundColor Yellow
    $installerUrl = "https://www.python.org/ftp/python/3.12.1/python-3.12.1-amd64.exe"
    $installerPath = "$env:TEMP\python_installer.exe"
    
    try {
        Write-Host "Downloading Python Installer..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        
        Write-Host "Installing Python (Silent)... This may take a minute."
        # /quiet: Silent
        # InstallAllUsers=1: Install for all users (Program Files) -> easier to find
        # PrependPath=1: Add to PATH
        $args = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
        $proc = Start-Process -FilePath $installerPath -ArgumentList $args -Wait -PassThru
        
        if ($proc.ExitCode -eq 0) {
             Write-Host "Python Direct Install Success." -ForegroundColor Green
             # Refresh PATH manually for this session
             $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
             return $true
        } else {
             Write-Host "Python Install Failed. Exit Code: $($proc.ExitCode)" -ForegroundColor Red
             return $false
        }
    } catch {
        Write-Host "[ERROR] Download or Install failed: $_" -ForegroundColor Red
        return $false
    }
}

# Check Python first
if (Test-Command "python") {
    $pyVer = python --version 2>&1
    Write-Host "Python is already installed: $pyVer" -ForegroundColor Cyan
} else {
    Write-Host "Python not found. Attempting install..."
    
    # Method 1: Winget
    if (Test-Command "winget") {
        Write-Host "Method 1: Winget (Store/Package Manager)"
        # Try generic Python 3
        winget install -e --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
             Write-Host "[WARNING] Winget failed. Trying fallback..." -ForegroundColor Yellow
             
             # Method 2: Direct Download
             if (-not (Install-Python-Fallback)) {
                 Write-Host "[CRITICAL ERROR] Python could not be installed." -ForegroundColor Red
                 Write-Host "Please install Python 3.12 manually from python.org"
                 Write-Host "Press Enter to exit..."
                 Read-Host
                 exit 1
             }
        }
    } else {
        # Method 2 Only
        Write-Host "[INFO] Winget not found. Using direct installer."
        if (-not (Install-Python-Fallback)) {
             Write-Host "[CRITICAL ERROR] Python could not be installed." -ForegroundColor Red
             exit 1
        }
    }
}

# Verify again
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
if (-not (Test-Command "python")) {
     Write-Host "[WARNING] Python installed but not found in PATH yet." -ForegroundColor Yellow
     Write-Host "A reboot will be required."
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
