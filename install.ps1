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
# 2. Unblock Files & Antivirus Exclusion
# ---------------------------------------------------------
Write-Host "Step 2: Unblocking files in $InstallDir..." -ForegroundColor Green
# CRITICAL FIX: Explicitly target the install directory, not System32
Get-ChildItem -Path $InstallDir -Recurse | Unblock-File
Write-Host "Files unblocked."
Write-Host ""

# Add Windows Defender Exclusion (reduces false positives)
Write-Host "Step 2b: Configuring antivirus exclusions..." -ForegroundColor Green
try {
    # Add folder to Windows Defender exclusions
    Add-MpPreference -ExclusionPath $InstallDir -ErrorAction Stop
    Write-Host "✓ Added to Windows Defender exclusions: $InstallDir" -ForegroundColor Green
    
    # Add Python scripts to process exclusions
    $pythonExe = "python.exe"
    Add-MpPreference -ExclusionProcess $pythonExe -ErrorAction SilentlyContinue
    Write-Host "✓ Added Python to process exclusions" -ForegroundColor Green
} catch {
    Write-Host "[INFO] Could not add Windows Defender exclusions (may not be available on this system)" -ForegroundColor Yellow
    Write-Host "      If you encounter issues, manually add this folder to your antivirus exclusions:" -ForegroundColor Yellow
    Write-Host "      $InstallDir" -ForegroundColor White
}

Write-Host ""
Write-Host "IMPORTANT: For Norton, McAfee, or other antivirus software:" -ForegroundColor Yellow
Write-Host "If installation is blocked, please add this folder to exclusions:" -ForegroundColor Yellow
Write-Host "  Folder: $InstallDir" -ForegroundColor White
Write-Host ""
Write-Host "Quick Guide:" -ForegroundColor Cyan
Write-Host "  Norton:  Settings > Antivirus > Scans and Risks > Exclusions" -ForegroundColor Gray
Write-Host "  McAfee:  Settings > Real-Time Scanning > Excluded Files" -ForegroundColor Gray
Write-Host "  Avast:   Menu > Settings > General > Exclusions" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------
# 3. Check/Install Dependencies (Winget)
# ---------------------------------------------------------
Write-Host "Step 3: Checking Dependencies..." -ForegroundColor Green

function Test-Command ($command) {
    return (Get-Command $command -ErrorAction SilentlyContinue)
}

# Check Python first - expanded search locations
$localAppData = [System.Environment]::GetEnvironmentVariable("LocalAppData")
$programFiles = [System.Environment]::GetEnvironmentVariable("ProgramFiles")
$programFilesX86 = [System.Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
$appData = [System.Environment]::GetEnvironmentVariable("AppData")

$pythonSearchPaths = @(
    "$localAppData\Microsoft\WindowsApps\python.exe",
    "$localAppData\Microsoft\WindowsApps\python3.exe",
    "$localAppData\Programs\Python\Python312\python.exe",
    "$localAppData\Programs\Python\Python311\python.exe",
    "$localAppData\Programs\Python\Python310\python.exe",
    "$programFiles\Python312\python.exe",
    "$programFiles\Python311\python.exe",
    "$programFiles\Python310\python.exe",
    "C:\Python312\python.exe",
    "C:\Python311\python.exe",
    "C:\Python310\python.exe"
)

$isPythonInstalled = $false
$foundPythonPath = $null

function Verify-Python ($path) {
    if (-not (Test-Path $path)) { return $false }
    try {
        # Check if it's a stub by seeing if it runs
        $output = & $path --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $output -match "Python \d+\.\d+") { 
            return $true 
        }
    } catch {
        return $false
    }
    return $false
}

# 1. Check Standard PATH
if (Test-Command "python") {
    try {
        $verCmd = python --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $verCmd -match "Python \d+\.\d+") {
            Write-Host "✓ Python found in PATH: $verCmd" -ForegroundColor Green
            $isPythonInstalled = $true
        }
    } catch { }
} 

# 2. Check py launcher
if (-not $isPythonInstalled -and (Test-Command "py")) {
    try {
        $verCmd = py --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $verCmd -match "Python \d+\.\d+") {
            Write-Host "✓ Python launcher (py.exe) found: $verCmd" -ForegroundColor Green
            $isPythonInstalled = $true
        }
    } catch { }
} 

# 3. Search common installation paths
if (-not $isPythonInstalled) {
    Write-Host "Searching for Python in common locations..." -ForegroundColor Cyan
    foreach ($path in $pythonSearchPaths) {
        if (Verify-Python $path) {
            $verCmd = & $path --version 2>&1
            Write-Host "✓ Python found at: $path ($verCmd)" -ForegroundColor Green
            $foundPythonPath = $path
            $isPythonInstalled = $true
            break
        }
    }
}

if (-not $isPythonInstalled) {
    Write-Host "Python not found. Attempting automatic installation..." -ForegroundColor Yellow
    
    # Skip winget altogether - use direct download (more reliable)
    $pythonUrl = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe"
    $installerPath = "$env:TEMP\python-installer.exe"
    
    try {
        Write-Host "Downloading Python 3.12.10 from python.org..." -ForegroundColor Cyan
        Write-Host "File size: ~25.7 MB (may take 1-3 minutes depending on connection speed)" -ForegroundColor Gray
        
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing -TimeoutSec 600
        $ProgressPreference = 'Continue'
        
        if (Test-Path $installerPath) {
            $fileSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "Downloaded successfully: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
            Write-Host "Installing Python 3.12.10 (this may take 2-3 minutes)..." -ForegroundColor Cyan
            
            # Run installer
            $process = Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -PassThru -Wait
            
            if ($process.ExitCode -eq 0) {
                Write-Host "Python installed successfully!" -ForegroundColor Green
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "[WARNING] Installer exited with code: $($process.ExitCode)" -ForegroundColor Yellow
                Write-Host "Python may still be installed. Continuing..." -ForegroundColor Yellow
            }
        } else {
            Write-Host "[ERROR] Download file not found after download attempt." -ForegroundColor Red
        }
    } catch {
        Write-Host "" -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        Write-Host "  AUTOMATIC INSTALLATION FAILED" -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "" -ForegroundColor Yellow
        Write-Host "MANUAL INSTALLATION REQUIRED:" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Option 1 - Download from Python.org (RECOMMENDED):" -ForegroundColor Cyan
        Write-Host "  1. Open browser and go to: https://www.python.org/downloads/" -ForegroundColor White
        Write-Host "  2. Click 'Download Python 3.12'" -ForegroundColor White
        Write-Host "  3. Run the installer" -ForegroundColor White
        Write-Host "  4. ✓ CHECK 'Add Python to PATH' during installation!" -ForegroundColor Green
        Write-Host "  5. After install, run this script again" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Option 2 - Use Microsoft Store:" -ForegroundColor Cyan
        Write-Host "  1. Open Microsoft Store app" -ForegroundColor White
        Write-Host "  2. Search for 'Python 3.12'" -ForegroundColor White
        Write-Host "  3. Click 'Get' or 'Install'" -ForegroundColor White
        Write-Host "  4. After install, run this script again" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Option 3 - Portable/Offline Installation:" -ForegroundColor Cyan
        Write-Host "  1. Download from another PC with internet" -ForegroundColor White
        Write-Host "  2. Copy installer to USB drive" -ForegroundColor White
        Write-Host "  3. Run installer on this PC" -ForegroundColor White
        Write-Host "  4. Make sure to add to PATH" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow
        Write-Host "============================================" -ForegroundColor Red
        Write-Host "" -ForegroundColor Yellow
        $choice = Read-Host "Continue anyway? (y/n)"
        if ($choice -ne "y" -and $choice -ne "Y") {
            Write-Host "Installation cancelled. Please install Python manually and re-run." -ForegroundColor Yellow
            Read-Host "Press Enter to exit..."
            exit 1
        }
    }
    
    # Verify installation
    Write-Host "Verifying Python installation..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (Test-Command "python") {
        $verCheck = python --version 2>&1
        Write-Host "✓ Python Installed Successfully: $verCheck" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Python not found in PATH yet." -ForegroundColor Yellow
        Write-Host "A system reboot may be required to complete installation." -ForegroundColor Yellow
        Write-Host "After reboot, run this script again." -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ Skipping Python install (Verified working)." -ForegroundColor Green
}

# Install SumatraPDF
Write-Host ""
Write-Host "Step 3b: Checking SumatraPDF..." -ForegroundColor Green

# Check if SumatraPDF already exists
$sumatraLocations = @(
    "C:\Program Files\SumatraPDF\SumatraPDF.exe",
    "C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe",
    "$localAppData\SumatraPDF\SumatraPDF.exe",
    "$localAppData\Programs\SumatraPDF\SumatraPDF.exe"
)

$sumatraFound = $false
foreach ($loc in $sumatraLocations) {
    if (Test-Path $loc) {
        Write-Host "✓ SumatraPDF found at: $loc" -ForegroundColor Green
        $sumatraFound = $true
        break
    }
}

if (-not $sumatraFound) {
    Write-Host "SumatraPDF not found. Attempting installation..." -ForegroundColor Yellow
    
    if (Test-Command "winget") {
        Write-Host "Installing SumatraPDF via winget..." -ForegroundColor Cyan
        $process = Start-Process -FilePath "winget" -ArgumentList "install -e --id SumatraPDF.SumatraPDF --source winget --accept-package-agreements --accept-source-agreements" -PassThru -Wait -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "✓ SumatraPDF installed successfully." -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Winget installation failed." -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            Write-Host "MANUAL INSTALLATION REQUIRED:" -ForegroundColor Yellow
            Write-Host "1. Download from: https://www.sumatrapdfreader.org/download-free-pdf-viewer" -ForegroundColor White
            Write-Host "2. Run the installer (portable or installer version)" -ForegroundColor White
            Write-Host "3. The application will auto-detect it on first run" -ForegroundColor White
            Write-Host "" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARNING] Winget not available. Manual installation required." -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "MANUAL INSTALLATION REQUIRED:" -ForegroundColor Yellow
        Write-Host "1. Download from: https://www.sumatrapdfreader.org/download-free-pdf-viewer" -ForegroundColor White
        Write-Host "2. Run the installer (portable or installer version)" -ForegroundColor White
        Write-Host "3. The application will auto-detect it on first run" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ Skipping SumatraPDF install (Already installed)." -ForegroundColor Green
}

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
