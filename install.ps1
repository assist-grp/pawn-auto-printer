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
# 3. Check/Install Dependencies (Winget)
# ---------------------------------------------------------
Write-Host "Step 3: Checking Dependencies..." -ForegroundColor Green

function Test-Command ($command) {
    return (Get-Command $command -ErrorAction SilentlyContinue)
}

# Check Python first
$localAppData = [System.Environment]::GetEnvironmentVariable("LocalAppData")
$windowsAppsPy = "$localAppData\Microsoft\WindowsApps\python.exe"
$windowsAppsPy3 = "$localAppData\Microsoft\WindowsApps\python3.exe"

$isPythonInstalled = $false

function Verify-Python ($path) {
    if (-not (Test-Path $path)) { return $false }
    try {
        # Check if it's a stub by seeing if it runs
        $process = Start-Process -FilePath $path -ArgumentList "--version" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) { return $true }
    } catch {
        return $false
    }
    return $false
}

# 1. Check Standard PATH
if (Test-Command "python") {
    $verCmd = python --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Python found in PATH: $verCmd" -ForegroundColor Cyan
        $isPythonInstalled = $true
    }
} 

# 2. Check py launcher
if (-not $isPythonInstalled -and (Test-Command "py")) {
    $verCmd = py --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Python launcher (py.exe) found: $verCmd" -ForegroundColor Cyan
        $isPythonInstalled = $true
    }
} 

# 3. Check WindowsApps explicitly (Verify it's not a stub)
if (-not $isPythonInstalled) {
    if (Verify-Python $windowsAppsPy) {
        Write-Host "Python found in WindowsApps (Verified)." -ForegroundColor Cyan
        $isPythonInstalled = $true
    } elseif (Verify-Python $windowsAppsPy3) {
        Write-Host "Python3 found in WindowsApps (Verified)." -ForegroundColor Cyan
        $isPythonInstalled = $true
    }
}

if (-not $isPythonInstalled) {
    Write-Host "Python not found or broken (Stub detected). Attempting install via winget..."
    if (Test-Command "winget") {
        # Try generic Python 3 first
        winget install -e --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
             Write-Host "[WARNING] Failed to install 'Python.Python.3'. Trying 'Python.Python.3.12'..." -ForegroundColor Yellow
             winget install -e --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements
        }
        
        # Verify success after install
        Write-Host "Verifying installation..."
        if (Verify-Python "python") {
            Write-Host "Python Installed Successfully." -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Python installed but not yet recognizable. A reboot is highly recommended." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERROR] 'winget' not found and Python is missing." -ForegroundColor Red
        Write-Host "Please install Python manually from python.org"
    }
} else {
    Write-Host "Skipping Python install (Verified working)."
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
    
    # Try different python commands for pip
    $pipCmd = "python"
    
    if (-not (Test-Command "python")) {
        if (Test-Command "py") {
             $pipCmd = "py"
        } elseif (Test-Path $windowsAppsPy) {
             $f = Get-Item $windowsAppsPy
             if ($f.Length -gt 0) {
                 $pipCmd = "`"$windowsAppsPy`""
             }
        }
    }
    
    Write-Host "Running pip install using: $pipCmd"
    Write-Host "This may take 2-3 minutes. Please wait..." -ForegroundColor Yellow
    Write-Host ""
    
    # Invoke-Expression is sometimes flagged, but simple arguments are usually ok
    if ($pipCmd -match "WindowsApps") {
        Write-Host "[1/2] Upgrading pip..."
        Start-Process -FilePath $windowsAppsPy -ArgumentList "-m pip install --upgrade pip --timeout 60 --no-cache-dir" -Wait -NoNewWindow
        
        Write-Host "[2/2] Installing packages individually..."
        $packages = @("watchdog", "pystray", "Pillow", "pywin32")
        foreach ($pkg in $packages) {
            Write-Host "  Installing $pkg..." -NoNewline
            $proc = Start-Process -FilePath $windowsAppsPy -ArgumentList "-m pip install $pkg --timeout 60 --no-cache-dir" -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -eq 0) {
                Write-Host " OK" -ForegroundColor Green
            } else {
                Write-Host " FAILED (will retry on first run)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "[1/2] Upgrading pip..."
        & $pipCmd -m pip install --upgrade pip --timeout 60 --no-cache-dir
        
        Write-Host "[2/2] Installing packages individually..."
        $packages = @("watchdog", "pystray", "Pillow", "pywin32")
        foreach ($pkg in $packages) {
            Write-Host "  Installing $pkg..." -NoNewline
            try {
                & $pipCmd -m pip install $pkg --timeout 60 --no-cache-dir 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " OK" -ForegroundColor Green
                } else {
                    Write-Host " FAILED (will retry on first run)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host " ERROR: $_" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "Pip install complete." -ForegroundColor Green

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
    
    # Delete existing shortcut if it exists
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "Removed existing shortcut"
    }
    
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "wscript.exe"
    $Shortcut.Arguments = "`"$TargetScript`""
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Save()
    
    Write-Host "Startup shortcut created: $ShortcutPath" -ForegroundColor Green
    Write-Host "Target: wscript.exe `"$TargetScript`"" -ForegroundColor Cyan
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
