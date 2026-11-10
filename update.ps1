# Pawn Auto Printer - one-shot updater
#
# Run from ANY folder in PowerShell (no need to cd into the app folder):
#   [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/update.ps1 | iex
#
# What it does:
#   1. Finds the app folder(s): running app / scheduled task "PDFAutoPrinter" /
#      Startup and Desktop shortcuts. If none is found, searches the disk.
#   2. Downloads the latest auto_printer.py from GitHub and replaces it
#      (the old one is kept as auto_printer.py.bak).
#   3. Checks that the app (running without admin rights) can write to its folder,
#      which automatic updates need.
#   4. Restarts the app and shows the VERSION line from printer_log.txt.
# config.json (printer settings) and other files are NOT touched.
#
# This file is ASCII only on purpose (safe for Windows PowerShell 5.1 and "irm | iex").
# Do not use "exit" here: with "irm | iex" it would close the user's PowerShell window.

& {
    $ErrorActionPreference = 'Stop'
    $url = 'https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/auto_printer.py'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    Write-Host ''
    Write-Host '=== Pawn Auto Printer updater ===' -ForegroundColor Cyan

    # ---------- 1. Find the app folder(s) ----------
    $found = [ordered]@{}   # lower-case path -> @{ Path; Source }

    function Add-AppFolder($dir, $source) {
        if (-not $dir) { return }
        try { $full = (Resolve-Path -LiteralPath $dir -ErrorAction Stop).ProviderPath.TrimEnd('\') } catch { return }
        if (-not (Test-Path -LiteralPath (Join-Path $full 'auto_printer.py'))) { return }
        if (-not (Test-Path -LiteralPath (Join-Path $full 'start_hidden.vbs'))) { return }
        $key = $full.ToLowerInvariant()
        if (-not $found.Contains($key)) {
            $found[$key] = [pscustomobject]@{ Path = $full; Source = $source }
        }
    }

    function Get-AppProcesses {
        @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and $_.CommandLine -like '*auto_printer.py*' })
    }

    # (a) The running app. start_hidden.vbs launches:
    #     cmd /c python auto_printer.py 2> "<folder>\startup_error.txt"
    foreach ($p in Get-AppProcesses) {
        if ($p.CommandLine -match '"([^"]+)\\startup_error\.txt"') { Add-AppFolder $Matches[1] 'running app' }
        if ($p.CommandLine -match '([A-Za-z]:\\[^"]*?)\\auto_printer\.py') { Add-AppFolder $Matches[1] 'running app' }
    }

    # (b) Scheduled task created by register_autostart.bat
    try {
        foreach ($a in (Get-ScheduledTask -TaskName 'PDFAutoPrinter' -ErrorAction Stop).Actions) {
            if ("$($a.Execute) $($a.Arguments)" -match '([A-Za-z]:\\[^"]*?)\\start_hidden\.vbs') {
                Add-AppFolder $Matches[1] 'scheduled task'
            }
        }
    } catch {}

    # (c) Startup shortcut (install.ps1) and Desktop shortcut (create_desktop_shortcut.bat)
    try {
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($sf in 'Startup', 'CommonStartup', 'Desktop', 'CommonDesktopDirectory') {
            $d = [Environment]::GetFolderPath($sf)
            if (-not $d -or -not (Test-Path -LiteralPath $d)) { continue }
            foreach ($lnk in @(Get-ChildItem -LiteralPath $d -Filter *.lnk -ErrorAction SilentlyContinue)) {
                try { $s = $wsh.CreateShortcut($lnk.FullName) } catch { continue }
                if ("$($s.TargetPath) $($s.Arguments)" -match '([A-Za-z]:\\[^"]*?)\\start_hidden\.vbs') {
                    Add-AppFolder $Matches[1] "shortcut: $($lnk.Name)"
                }
            }
        }
    } catch {}

    # (d) Nothing registered: search the user folder and top-level folders of the system drive
    if ($found.Count -eq 0) {
        Write-Host 'App folder not registered. Searching the disk (may take a minute)...'
        $skip = @('Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', 'Users',
                  '$Recycle.Bin', 'Recovery', 'PerfLogs', 'System Volume Information')
        $roots = @()
        $roots += @(Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'AppData' })
        $roots += @(Get-ChildItem -LiteralPath ($env:SystemDrive + '\') -Directory -ErrorAction SilentlyContinue |
            Where-Object { $skip -notcontains $_.Name })
        foreach ($r in $roots) {
            foreach ($f in @(Get-ChildItem -LiteralPath $r.FullName -Recurse -Depth 6 -Filter 'start_hidden.vbs' -File -ErrorAction SilentlyContinue)) {
                Add-AppFolder $f.DirectoryName 'disk search'
            }
        }
    }

    if ($found.Count -eq 0) {
        Write-Host '[ERROR] App folder (auto_printer.py + start_hidden.vbs) was not found on this PC / user.' -ForegroundColor Red
        Write-Host '        If the app runs under another Windows user, sign in as that user and run this again.'
        return
    }

    Write-Host ''
    Write-Host 'App folder(s) found:'
    foreach ($f in $found.Values) { Write-Host ("  {0}   [{1}]" -f $f.Path, $f.Source) }

    # ---------- 2. Download and replace ----------
    $tmp = Join-Path $env:TEMP ('auto_printer_' + [guid]::NewGuid().ToString('N') + '.py')
    try {
        (New-Object Net.WebClient).DownloadFile($url + '?t=' + (Get-Date).Ticks, $tmp)
    } catch {
        Write-Host "[ERROR] Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    $text = [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8)
    if ($text -notmatch 'def _self_update' -or $text -notmatch 'class PDFHandler') {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Write-Host '[ERROR] Downloaded file does not look like auto_printer.py. Nothing was changed.' -ForegroundColor Red
        return
    }
    $newVersion = if ($text -match 'APP_VERSION = "([^"]+)"') { $Matches[1] } else { '?' }
    $newHash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash

    # The app runs WITHOUT admin rights, so self-update only works if a normal user can write
    # to the app folder (Program Files usually does not allow that).
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    function Test-Writable($dir) {
        $probe = Join-Path $dir ('write_test_' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::WriteAllText($probe, 'test')
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            return $true
        } catch {
            return $false
        }
    }
    $allWritable = $true
    $ic = [StringComparison]::OrdinalIgnoreCase
    $moveCmd = "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/move_to_documents.ps1 | iex"
    $downloads = $null
    try { $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch {}
    if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }
    $downloads = $downloads.TrimEnd('\')

    Write-Host ''
    Write-Host "Latest version on GitHub: $newVersion (sha256 $($newHash.Substring(0, 8).ToLower()))"
    foreach ($f in $found.Values) {
        $target = Join-Path $f.Path 'auto_printer.py'
        try {
            if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $newHash) {
                Write-Host "  [OK] already latest: $target" -ForegroundColor Green
            } else {
                Copy-Item -LiteralPath $target -Destination ($target + '.bak') -Force
                Copy-Item -LiteralPath $tmp -Destination $target -Force
                Write-Host "  [OK] updated: $target" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [ERROR] could not update $target : $($_.Exception.Message)" -ForegroundColor Red
        }
        if (-not $isAdmin) {
            if (Test-Writable $f.Path) {
                Write-Host '  [OK] auto-update can write to this folder' -ForegroundColor Green
            } else {
                $allWritable = $false
                Write-Host '  [WARN] auto-update CANNOT write to this folder (admin rights needed).' -ForegroundColor Yellow
                if ($f.Path -match '^[A-Za-z]:\\Program Files') {
                    Write-Host '         The app stays in Program Files, so it will not update itself.' -ForegroundColor Yellow
                    Write-Host '         To update it, open PowerShell with "Run as administrator" and run this update command.' -ForegroundColor Yellow
                } else {
                    Write-Host '         The app will stay on the old version. Move it into the Documents folder with this command:' -ForegroundColor Yellow
                    Write-Host "         $moveCmd"
                }
            }
        }
        if ($f.Path.StartsWith($downloads + '\', $ic)) {
            Write-Host '  [NOTE] The app is inside the Downloads folder. It may be deleted when Downloads is cleaned up.' -ForegroundColor Yellow
            Write-Host '         Move it into the Documents folder with this command:' -ForegroundColor Yellow
            Write-Host "         $moveCmd"
        }
    }
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    if ($isAdmin) {
        Write-Host '  [NOTE] PowerShell is running as administrator, so the folder write check was skipped.' -ForegroundColor Yellow
        Write-Host '         Run this command again in a normal (non-admin) PowerShell to check it.' -ForegroundColor Yellow
    }

    # ---------- 3. Restart the app ----------
    $primary = @($found.Values)[0]   # running app > scheduled task > shortcut > disk search
    Write-Host ''
    Write-Host "Restarting the app: $($primary.Path)"
    foreach ($p in Get-AppProcesses) {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Seconds 2

    $logName = 'printer_log.txt'
    try {
        $cfg = Get-Content -LiteralPath (Join-Path $primary.Path 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.log_file) { $logName = $cfg.log_file }
    } catch {}
    $logPath = if ([IO.Path]::IsPathRooted($logName)) { $logName } else { Join-Path $primary.Path $logName }

    $startedAt = (Get-Date).AddSeconds(-1)
    Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + (Join-Path $primary.Path 'start_hidden.vbs') + '"') -WorkingDirectory $primary.Path

    # Wait for the new process to write its VERSION line
    $lines = @()
    for ($i = 0; $i -lt 30 -and $lines.Count -eq 0; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Test-Path -LiteralPath $logPath)) { continue }
        $lines = @(Get-Content -LiteralPath $logPath -Tail 50 -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object {
            if ($_ -notmatch '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - (VERSION|AUTO UPDATE):') { return $false }
            try { [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null) -ge $startedAt } catch { $false }
        })
        if (-not ($lines -match 'VERSION:')) { $lines = @() }
    }

    Write-Host ''
    if ($lines.Count -gt 0) {
        foreach ($l in $lines) { Write-Host "  $l" }
        Write-Host ''
        Write-Host 'Done. The app is running with the latest version.' -ForegroundColor Green
        if ($isAdmin) {
            Write-Host 'Automatic updates: not checked (see [NOTE] above).' -ForegroundColor Yellow
        } elseif ($allWritable) {
            Write-Host 'From now on it updates itself automatically every time it starts.'
        } else {
            Write-Host 'Automatic updates will NOT work in this folder (see [WARN] above).' -ForegroundColor Yellow
        }
        # Downloads / move hints were printed above; repeat them at the end so they are not missed
        foreach ($f in $found.Values) {
            if ($f.Path.StartsWith($downloads + '\', $ic)) {
                Write-Host ''
                Write-Host 'Recommended: move the app out of the Downloads folder (see [NOTE] above).' -ForegroundColor Yellow
                break
            }
        }
    } else {
        Write-Host '[WARN] The app did not write its VERSION line within 30 seconds.' -ForegroundColor Yellow
        Write-Host "       Check startup_debug.txt / startup_error.txt in: $($primary.Path)"
    }
    Write-Host ''
}
