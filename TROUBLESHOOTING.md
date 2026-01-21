# Pawn Auto Printer - Troubleshooting Guide

## Quick Diagnostic

Run this to check system status:
```cmd
verify_installation.bat
```

Then check the detailed log:
```cmd
type printer_log.txt
```

---

## Common Issues

### ❌ "Python not found" Error

**Symptoms:** All scripts fail with "Python not found"

**Root Causes:**
1. Python not installed
2. Python not added to PATH
3. Windows "stub" Python from Microsoft Store

**Solutions:**

Option A: Install Python properly
```powershell
# Download from https://www.python.org/
# CRITICAL: During installation, check "Add Python to PATH"
# Then restart your computer
```

Option B: Use py launcher
```cmd
py --version    # Should show version
py -m pip --version
```

Option C: Reinstall via winget
```cmd
winget install Python.Python.3.12
```

Then restart and run:
```cmd
run_printer.bat
```

---

### ❌ "Dependencies not installed" / Import Errors

**Symptoms:**
```
ModuleNotFoundError: No module named 'watchdog'
```
or `startup_error.txt` appears

**Solutions:**

```cmd
:: Upgrade pip first
python -m pip install --upgrade pip

:: Install all packages
python -m pip install watchdog pystray Pillow pywin32

:: Try with py launcher if above fails
py -m pip install watchdog pystray Pillow pywin32
```

Then delete `startup_error.txt` and restart:
```cmd
run_printer.bat
```

---

### ⚠️ "SumatraPDF not found" Warning

**Symptoms:**
- Application runs but files don't print
- Log shows: "ERROR: SumatraPDF not found"

**Solutions:**

1. Install SumatraPDF
   - Download: https://www.sumatrapdfreader.org/
   - Install to: `C:\Program Files\SumatraPDF\`

2. Or manually update `config.json`:
   ```json
   {
       "sumatra_path": "C:/Program Files/SumatraPDF/SumatraPDF.exe"
   }
   ```

3. Verify in debug mode:
```cmd
debug_runner.bat
```

---

### ⚠️ "No browser found" Warning

**Symptoms:**
- HTML files not converting to PDF
- Log shows: "ERROR: No compatible browser (Edge/Chrome) found"

**Solutions:**

1. Install Edge or Chrome:
   - Edge: https://www.microsoft.com/edge
   - Chrome: https://www.google.com/chrome

2. Or manually set in `config.json`:
   ```json
   {
       "browser_path": "C:/Program Files/Microsoft/Edge/Application/msedge.exe"
   }
   ```

3. Verify path exists:
   ```cmd
   dir "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
   ```

---

### ❌ Files Not Printing

**Symptoms:** Files detected but not printed

**Checklist:**

1. **Filename contains paper size marker?**
   ```
   ✓ document_PRINT_A4.pdf       → Will print
   ✓ report_PRINT_A5.html        → Will convert and print
   ✗ document.pdf                → Ignored
   ✗ PRINT_document.pdf          → Ignored (marker must be in name)
   ```

2. **Check log for clues:**
   ```cmd
   type printer_log.txt
   ```
   Look for: DETECTED, PROCESSING, PRINT SUCCESS, or ERROR lines

3. **Wrong file format?**
   - PDF: Plain PDF file (text, images)
   - HTML: Valid HTML file (test in browser first)

4. **Printer offline?**
   ```cmd
   Get-Printer   # PowerShell
   ```

5. **File permissions?**
   - File must be readable
   - Destination folder must be writable
   - Try moving file to `Downloads` temporarily

---

### ❌ File Not Detected

**Symptoms:**
- Files in watch directory but nothing happens
- Log shows: "IGNORED: filename"

**Solutions:**

1. Check filename - must contain `PRINT_A4` or `PRINT_A5` (case-insensitive)

2. Check watch_directory in `config.json`:
   ```json
   {
       "watch_directory": "C:/Users/YourName/Downloads"
   }
   ```

3. Verify directory exists:
   ```cmd
   dir "C:\Users\YourName\Downloads"
   ```

4. Try placing test file directly in app directory:
   ```cmd
   type nul > test_PRINT_A4.pdf
   ```

5. Run in debug mode to see all events:
   ```cmd
   debug_runner.bat
   ```

---

### ❌ "File is locked" / No Processing

**Symptoms:**
- File appears but never processes
- Multiple watchdog events but no action

**Root Causes:**
- File still being written (incomplete download)
- Another program using file
- File size is 0 bytes

**Solutions:**

1. Wait for file to finish writing/downloading
   - App will automatically retry on `on_modified` events

2. Restart application:
   ```cmd
   stop_printer.bat
   run_printer.bat
   ```

3. Check file not empty:
   ```cmd
   dir test_file.pdf
   ```

4. If persistent, try copying file with new name:
   ```cmd
   copy old_file_PRINT_A4.pdf new_file_PRINT_A4.pdf
   ```

---

### ⚠️ Duplicate Printing

**Symptoms:** Same file printed multiple times

**Root Causes:**
1. File re-downloaded/renamed by browser/app
2. Watchdog event fired multiple times
3. Processing lock released before file deleted

**Solutions:**

1. Set `auto_delete` in `config.json`:
   ```json
   {
       "auto_delete": true
   }
   ```

2. Check `printer_log.txt` for multiple DETECTED lines

3. Clear `processed_files` set by restarting:
   ```cmd
   stop_printer.bat
   run_printer.bat
   ```

---

### ❌ Tray Icon Not Appearing

**Symptoms:**
- App runs but no system tray icon
- Can't select printer via GUI

**Root Causes:**
- `app_icon.png` missing
- PIL/Pillow not installed properly
- Windows theme issue

**Solutions:**

1. Verify icon file exists:
   ```cmd
   dir app_icon.png
   ```

2. Reinstall Pillow:
   ```cmd
   python -m pip install --force-reinstall Pillow
   ```

3. App still functions without icon - use `config.json` to set printer:
   ```json
   {
       "target_printer": "Canon Pixma MX490"
   }
   ```

4. Run debug to verify:
   ```cmd
   debug_runner.bat
   ```

---

### ⚠️ "Access Denied" / Permission Errors

**Symptoms:**
- "Permission denied" in logs
- Can't write to watched directory

**Solutions:**

1. Run as Administrator:
   - Right-click `start_background.bat` → "Run as administrator"

2. Or check folder permissions:
   ```cmd
   icacls "C:\Users\YourName\Downloads"
   ```

3. Or change watch directory in `config.json` to a folder you control:
   ```json
   {
       "watch_directory": "C:/Users/YourName/Documents"
   }
   ```

---

### ❌ "Conversion failed" / HTML not converting

**Symptoms:**
- HTML files detected but not converted
- Log shows: "CONVERSION FAILED" or Edge/Chrome timeout

**Solutions:**

1. Test HTML file:
   - Open file in Edge/Chrome manually
   - Should display correctly
   - If not, fix HTML first

2. Verify browser can run:
   ```cmd
   "C:\Program Files\Microsoft\Edge\Application\msedge.exe" --version
   ```

3. Try simpler HTML:
   ```html
   <!DOCTYPE html>
   <html>
   <body>
   <h1>Test</h1>
   </body>
   </html>
   ```

4. Check file paths have no special characters:
   ✓ `test_PRINT_A4.html`
   ✗ `test PRINT_A4 (1).html`

5. Increase timeout (edit `auto_printer.py`):
   ```python
   subprocess.run(command, check=True, timeout=120)  # Changed from 60
   ```

6. Check disk space (conversion needs temp file):
   ```cmd
   dir C:\   # Check free space
   ```

---

## Advanced Debugging

### Enable All Logging

Edit `auto_printer.py` line ~52:
```python
logging.basicConfig(
    level=logging.DEBUG,  # Changed from INFO
    ...
)
```

### Check Running Processes

```cmd
tasklist | find "python"
tasklist | find "pythonw"
```

### View Real-Time Log

```powershell
Get-Content -Path "printer_log.txt" -Wait -Tail 20
```

### Restart Everything

```cmd
stop_printer.bat
del printer_log.txt
del config.json
del startup_error.txt
run_printer.bat
```

---

## Getting Help

1. **Check logs first:**
   ```cmd
   type printer_log.txt
   ```

2. **Run verification:**
   ```cmd
   verify_installation.bat
   ```

3. **Try debug mode:**
   ```cmd
   debug_runner.bat
   ```

4. **Review guides:**
   - `INSTALL_JP.md` (Japanese)
   - `INSTALL_EN.md` (English)

5. **Check project files:**
   - `0_Manual_JP.html` - User manual
   - `.github/copilot-instructions.md` - Architecture docs
