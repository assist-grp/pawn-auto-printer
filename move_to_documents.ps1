# Pawn Auto Printer - move the app folder into the Documents folder
#
# Run from ANY folder in a normal (non-admin) PowerShell:
#   [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/move_to_documents.ps1 | iex
#
# What it does:
#   1. Finds the app folder (same way as update.ps1).
#   2. Stops the app and copies the whole folder (config.json included) to
#      <Documents>\pawn-auto-printer, then checks the new folder is writable.
#   3. Points the auto-start entries to the new folder:
#      - Startup / Desktop shortcuts (no admin rights needed)
#      - scheduled task "PDFAutoPrinter" and the Windows Defender exclusion
#        (one administrator prompt)
#   4. Starts the app from the new folder and waits for its VERSION line.
#   5. Deletes the old folder, only when everything above succeeded.
# It does nothing when the app is already in Documents or in Program Files
# (PCs that use Program Files keep the app there).
#
# This file is ASCII only on purpose (safe for Windows PowerShell 5.1 and "irm | iex").
# Do not use "exit" here: with "irm | iex" it would close the user's PowerShell window.

& {
    $ErrorActionPreference = 'Stop'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}
    $ic = [StringComparison]::OrdinalIgnoreCase

    Write-Host ''
    Write-Host '=== Pawn Auto Printer: move the app to the Documents folder ===' -ForegroundColor Cyan

    # ---------- 1. Find the app folder (same logic as update.ps1) ----------
    $found = [ordered]@{}

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

    function Start-App($dir) {
        Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + (Join-Path $dir 'start_hidden.vbs') + '"') -WorkingDirectory $dir
    }

    foreach ($p in Get-AppProcesses) {
        if ($p.CommandLine -match '"([^"]+)\\startup_error\.txt"') { Add-AppFolder $Matches[1] 'running app' }
        if ($p.CommandLine -match '([A-Za-z]:\\[^"]*?)\\auto_printer\.py') { Add-AppFolder $Matches[1] 'running app' }
    }
    try {
        foreach ($a in (Get-ScheduledTask -TaskName 'PDFAutoPrinter' -ErrorAction Stop).Actions) {
            if ("$($a.Execute) $($a.Arguments)" -match '([A-Za-z]:\\[^"]*?)\\start_hidden\.vbs') {
                Add-AppFolder $Matches[1] 'scheduled task'
            }
        }
    } catch {}
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

    $src = @($found.Values)[0].Path   # running app > scheduled task > shortcut > disk search
    if ($found.Count -gt 1) {
        Write-Host 'More than one app folder was found:'
        foreach ($f in $found.Values) { Write-Host ("  {0}   [{1}]" -f $f.Path, $f.Source) }
        Write-Host "Only the one in use is moved: $src"
    }

    # ---------- 2. Decide the new folder and check that moving is safe ----------
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs -or -not (Test-Path -LiteralPath $docs)) {
        Write-Host '[ERROR] The Documents folder was not found. Nothing was changed.' -ForegroundColor Red
        return
    }
    $docs = $docs.TrimEnd('\')
    $dst = Join-Path $docs 'pawn-auto-printer'

    Write-Host ''
    Write-Host "Current app folder : $src"
    Write-Host "New app folder     : $dst"

    if ($src.StartsWith($docs + '\', $ic)) {
        Write-Host ''
        Write-Host '[OK] The app is already inside the Documents folder. Nothing to do.' -ForegroundColor Green
        Write-Host ''
        return
    }

    # Policy: PCs that run the app from Program Files keep it there.
    if ($src -match '^[A-Za-z]:\\Program Files') {
        Write-Host ''
        Write-Host '[OK] The app is in Program Files. PCs that use Program Files keep the app there. Nothing to do.' -ForegroundColor Green
        Write-Host ''
        return
    }

    # Never move a whole special folder (e.g. the app files were put directly into Downloads)
    $downloads = $null
    try { $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch {}
    if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }
    $protected = @($env:USERPROFILE, $downloads, $docs, [Environment]::GetFolderPath('Desktop'),
                   [Environment]::GetFolderPath('UserProfile'), ($env:SystemDrive + '\')) |
        Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
    foreach ($pp in $protected) {
        if ($src.TrimEnd('\').Equals($pp, $ic)) {
            Write-Host "[ERROR] The app files are directly inside $src (not in their own folder)." -ForegroundColor Red
            Write-Host '        It cannot be moved automatically. Nothing was changed. Please ask IT.'
            return
        }
    }
    $srcFiles = @(Get-ChildItem -LiteralPath $src -Recurse -Force -File -ErrorAction SilentlyContinue)
    $srcBytes = ($srcFiles | Measure-Object -Property Length -Sum).Sum
    if ($srcFiles.Count -gt 500 -or $srcBytes -gt 500MB) {
        Write-Host "[ERROR] $src contains many other files ($($srcFiles.Count) files)." -ForegroundColor Red
        Write-Host '        It cannot be moved automatically. Nothing was changed. Please ask IT.'
        return
    }

    $dstExisted = Test-Path -LiteralPath $dst
    if ($dstExisted -and @(Get-ChildItem -LiteralPath $dst -Force -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Host "[ERROR] $dst already exists and is not empty. Nothing was changed." -ForegroundColor Red
        Write-Host '        Rename or delete that folder, then run this command again.'
        return
    }

    # ---------- 3. Stop the app and copy ----------
    Write-Host ''
    Write-Host 'Stopping the app...'
    foreach ($p in Get-AppProcesses) {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Seconds 2

    Write-Host 'Copying files...'
    try {
        [void][IO.Directory]::CreateDirectory($dst)
        Get-ChildItem -LiteralPath $src -Force | Copy-Item -Destination $dst -Recurse -Force
        $srcCount = @(Get-ChildItem -LiteralPath $src -Recurse -Force -File).Count
        $dstCount = @(Get-ChildItem -LiteralPath $dst -Recurse -Force -File).Count
        if ($dstCount -lt $srcCount -or
            -not (Test-Path -LiteralPath (Join-Path $dst 'auto_printer.py')) -or
            -not (Test-Path -LiteralPath (Join-Path $dst 'start_hidden.vbs'))) {
            throw "copy incomplete ($dstCount of $srcCount files)"
        }
    } catch {
        Write-Host "[ERROR] Copy failed: $($_.Exception.Message)" -ForegroundColor Red
        if (-not $dstExisted) { try { Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction Stop } catch {} }
        Write-Host '        The old folder was not changed. Restarting the app from the old folder.'
        Start-App $src
        return
    }
    Write-Host "  [OK] copied $dstCount files" -ForegroundColor Green

    # If Documents is synced by OneDrive, keep the app files on this PC ("Always keep on this device")
    $oneDriveRoots = @($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer) | Where-Object { $_ }
    foreach ($od in $oneDriveRoots) {
        if ($dst.StartsWith($od.TrimEnd('\') + '\', $ic)) {
            try {
                & attrib.exe +P "$dst" | Out-Null
                & attrib.exe +P "$dst\*" /S /D | Out-Null
                Write-Host '  [OK] OneDrive: set "Always keep on this device"' -ForegroundColor Green
            } catch {}
            break
        }
    }

    $probe = Join-Path $dst ('write_test_' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'test')
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        Write-Host '  [OK] auto-update can write to the new folder' -ForegroundColor Green
    } catch {
        Write-Host '  [WARN] auto-update CANNOT write to the new folder. Please ask IT.' -ForegroundColor Yellow
    }

    # ---------- 4. Point shortcuts to the new folder ----------
    Write-Host ''
    Write-Host 'Updating shortcuts...'
    $startupOk = $false
    $pattern = [regex]::Escape($src) + '(?=\\|"|$)'
    $replacement = $dst.Replace('$', '$$')
    $anyShortcut = $false
    $shortcutFail = $false
    try {
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($sf in 'Startup', 'CommonStartup', 'Desktop', 'CommonDesktopDirectory') {
            $d = [Environment]::GetFolderPath($sf)
            if (-not $d -or -not (Test-Path -LiteralPath $d)) { continue }
            foreach ($lnk in @(Get-ChildItem -LiteralPath $d -Filter *.lnk -ErrorAction SilentlyContinue)) {
                try { $s = $wsh.CreateShortcut($lnk.FullName) } catch { continue }
                $hit = $false
                foreach ($prop in 'TargetPath', 'Arguments', 'WorkingDirectory', 'IconLocation') {
                    $v = [string]$s.$prop
                    if ($v -and [regex]::IsMatch($v, $pattern, 'IgnoreCase')) {
                        $s.$prop = [regex]::Replace($v, $pattern, $replacement, 'IgnoreCase')
                        $hit = $true
                    }
                }
                if (-not $hit) { continue }
                $anyShortcut = $true
                try {
                    $s.Save()
                    Write-Host "  [OK] updated: $($lnk.FullName)" -ForegroundColor Green
                    if ($sf -like '*Startup') { $startupOk = $true }
                } catch {
                    $shortcutFail = $true
                    Write-Host "  [WARN] could not update (admin rights needed): $($lnk.FullName)" -ForegroundColor Yellow
                }
            }
        }
    } catch {}
    if (-not $anyShortcut) { Write-Host '  (no shortcut points to the old folder)' }

    # ---------- 5. Scheduled task + Windows Defender exclusion (needs admin: one prompt) ----------
    Write-Host ''
    Write-Host 'Updating the auto-start task and the antivirus exclusion.'
    Write-Host 'Windows will ask for administrator permission. Please click "Yes".' -ForegroundColor Yellow

    function ConvertTo-PSLiteral($s) { "'" + ([string]$s).Replace("'", "''") + "'" }
    $newVbs = Join-Path $dst 'start_hidden.vbs'
    $resultFile = Join-Path $dst ('move_result_' + [guid]::NewGuid().ToString('N') + '.txt')
    $helper = @'
$out = @()
$vbs = __VBS__
$old = __OLD__
$new = __NEW__
$ic = [StringComparison]::OrdinalIgnoreCase
try {
    $t = Get-ScheduledTask -TaskName 'PDFAutoPrinter' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $t) {
        $out += 'TASK:NONE'
    } else {
        $a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $vbs + '"')
        Set-ScheduledTask -TaskName 'PDFAutoPrinter' -TaskPath $t.TaskPath -Action $a -ErrorAction Stop | Out-Null
        $out += 'TASK:OK'
    }
} catch { $out += ('TASK:FAIL ' + $_.Exception.Message) }
try {
    $ex = @((Get-MpPreference -ErrorAction Stop).ExclusionPath) | Where-Object { $_ }
    $covered = $false
    foreach ($e in $ex) {
        $e2 = ([string]$e).TrimEnd('\')
        if ($old.Equals($e2, $ic) -or $old.StartsWith($e2 + '\', $ic)) { $covered = $true }
    }
    if ($covered) {
        Add-MpPreference -ExclusionPath $new -ErrorAction Stop
        $out += 'AV:ADDED'
    } else {
        $out += 'AV:NOTNEEDED'
    }
} catch { $out += ('AV:SKIP ' + $_.Exception.Message) }
$out | Set-Content -LiteralPath __RESULT__ -Encoding UTF8
'@
    $helper = $helper.Replace('__VBS__', (ConvertTo-PSLiteral $newVbs)).Replace('__OLD__', (ConvertTo-PSLiteral $src)).Replace('__NEW__', (ConvertTo-PSLiteral $dst)).Replace('__RESULT__', (ConvertTo-PSLiteral $resultFile))
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($helper))

    $taskState = 'UNKNOWN'
    $avState = 'UNKNOWN'
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait `
            -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + $encoded) | Out-Null
        if (Test-Path -LiteralPath $resultFile) {
            foreach ($line in @(Get-Content -LiteralPath $resultFile -Encoding UTF8)) {
                if ($line -like 'TASK:*') { $taskState = $line.Substring(5) }
                if ($line -like 'AV:*') { $avState = $line.Substring(3) }
            }
            Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host '  [WARN] Administrator permission was not given.' -ForegroundColor Yellow
    }

    if ($taskState -eq 'UNKNOWN') {
        # Fallback without admin rights (works if this user may change the task)
        try {
            $t = Get-ScheduledTask -TaskName 'PDFAutoPrinter' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $t) {
                $taskState = 'NONE'
            } else {
                $a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $newVbs + '"')
                Set-ScheduledTask -TaskName 'PDFAutoPrinter' -TaskPath $t.TaskPath -Action $a -ErrorAction Stop | Out-Null
                $taskState = 'OK'
            }
        } catch {
            $taskState = 'FAIL ' + $_.Exception.Message
        }
    }

    if ($taskState -eq 'OK') {
        Write-Host '  [OK] auto-start task "PDFAutoPrinter" now uses the new folder' -ForegroundColor Green
    } elseif ($taskState -eq 'NONE') {
        Write-Host '  (no auto-start task "PDFAutoPrinter")'
    } else {
        Write-Host "  [WARN] could not update the auto-start task: $taskState" -ForegroundColor Yellow
    }
    if ($avState -eq 'ADDED') {
        Write-Host '  [OK] added the new folder to the Windows Defender exclusions' -ForegroundColor Green
    } elseif ($avState -eq 'NOTNEEDED') {
        Write-Host '  (the old folder had no Windows Defender exclusion; nothing to copy)'
    } else {
        Write-Host '  [NOTE] Could not check antivirus exclusions. If the old folder was excluded in your' -ForegroundColor Yellow
        Write-Host '         antivirus (Windows Defender, Norton, etc.), add the new folder there too.' -ForegroundColor Yellow
    }

    # ---------- 6. Start the app from the new folder ----------
    Write-Host ''
    Write-Host "Starting the app from: $dst"
    $logName = 'printer_log.txt'
    try {
        $cfg = Get-Content -LiteralPath (Join-Path $dst 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.log_file) { $logName = $cfg.log_file }
    } catch {}
    $logPath = if ([IO.Path]::IsPathRooted($logName)) { $logName } else { Join-Path $dst $logName }

    $startedAt = (Get-Date).AddSeconds(-1)
    Start-App $dst
    $lines = @()
    for ($i = 0; $i -lt 30 -and $lines.Count -eq 0; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Test-Path -LiteralPath $logPath)) { continue }
        $lines = @(Get-Content -LiteralPath $logPath -Tail 50 -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object {
            if ($_ -notmatch '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - (VERSION|AUTO UPDATE|Started monitoring):') { return $false }
            try { [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null) -ge $startedAt } catch { $false }
        })
        if (-not ($lines -match 'VERSION:')) { $lines = @() }
    }
    $started = $lines.Count -gt 0
    if ($started) {
        foreach ($l in $lines) { Write-Host "  $l" }
    } else {
        Write-Host '  [WARN] The app did not write its VERSION line within 30 seconds.' -ForegroundColor Yellow
        Write-Host "         Check startup_debug.txt / startup_error.txt in: $dst"
        if (@(Get-AppProcesses).Count -eq 0) {
            # Keep printing working: start the app again from the old folder (it is kept below)
            Write-Host '  [WARN] Restarting the app from the old folder so printing keeps working. Please ask IT.' -ForegroundColor Yellow
            Start-App $src
        }
    }

    # ---------- 7. Delete the old folder (only if everything worked) ----------
    Write-Host ''
    $taskBroken = -not ($taskState -eq 'OK' -or $taskState -eq 'NONE')
    if ($started -and -not $taskBroken -and -not $shortcutFail) {
        try {
            Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction Stop
            Write-Host "[OK] Deleted the old folder: $src" -ForegroundColor Green
            $parent = [IO.Path]::GetDirectoryName($src)
            if ($parent -and ([IO.Path]::GetFileName($parent) -like 'pawn-auto-printer*') -and
                @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                Remove-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Deleted the empty folder: $parent" -ForegroundColor Green
            }
        } catch {
            Write-Host "[WARN] Could not delete the old folder. Please delete it by hand: $src" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[NOTE] The old folder was kept: $src" -ForegroundColor Yellow
        if ($taskBroken) {
            Write-Host '       Open the NEW folder, right-click register_autostart.bat and choose "Run as administrator".' -ForegroundColor Yellow
        }
        if ($shortcutFail) {
            Write-Host '       Delete the shortcuts marked [WARN] above by hand (they still point to the old folder).' -ForegroundColor Yellow
        }
        if ($taskBroken -or $shortcutFail) {
            Write-Host '       After that, delete the old folder by hand.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    if ($started) {
        Write-Host "Done. The app now runs from: $dst" -ForegroundColor Green
        if (-not $startupOk -and $taskState -ne 'OK') {
            Write-Host '[WARN] No auto-start entry was found. To start the app automatically at sign-in,' -ForegroundColor Yellow
            Write-Host '       right-click register_autostart.bat in the new folder and choose "Run as administrator".' -ForegroundColor Yellow
        }
    }
    Write-Host ''
}
