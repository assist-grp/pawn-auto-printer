# Pawn Auto Printer - Windows Installation Guide

## Quick Start (Recommended)

### Step 1: Install Required Software

Choose one of the following methods:

#### Method A: Automated Installation (Recommended)
1. Double-click `install_all.bat`
2. Click "Yes" when prompted for **Administrator privileges**
3. Wait for installation to complete (5-10 minutes)

#### Method B: Manual Installation
1. **Install Python 3.9+**
   - Download from https://www.python.org/
   - **Important:** Check "Add Python to PATH" during installation

2. **Install SumatraPDF**
   - Download from https://www.sumatrapdfreader.org/
   - Install to default location (`C:\Program Files\SumatraPDF\`)

3. **Install Python Packages**
   - Open Command Prompt and run:
   ```cmd
   pip install watchdog pystray Pillow pywin32
   ```

### Step 2: Verify Installation

1. Double-click `verify_installation.bat`
2. Confirm all items show checkmarks (✓)

### Step 3: Initial Configuration

1. Open `config.json` with a text editor
2. Configure:
   ```json
   {
       "watch_directory": "C:/Users/YourName/Downloads",
       "sumatra_path": "C:/Program Files/SumatraPDF/SumatraPDF.exe",
       "log_file": "printer_log.txt",
       "auto_delete": true
   }
   ```
   - `watch_directory`: Folder to monitor (default: Downloads)
   - `sumatra_path`: Path to SumatraPDF executable
   - `auto_delete`: Delete original file after printing

### Step 4: Launch Application

Double-click `run_printer.bat` to start

## Daily Usage

### Run in Background (Recommended)
- Double-click `start_background.bat` → Runs hidden

### Debug Mode (Troubleshooting)
- Double-click `debug_runner.bat` → Shows console output

### Stop Application
- Double-click `stop_printer.bat`

## File Format

### Print PDF
- Filename must contain `PRINT_A4` or `PRINT_A5`
- Example: `document_PRINT_A4.pdf`

### Convert HTML and Print
- Place `.html` file in monitored folder
- Filename must contain `PRINT_A4` or `PRINT_A5`
- Example: `report_PRINT_A5.html` → Auto-converts to PDF and prints

## Troubleshooting

### Issue 1: File Not Printing
**Check:**
- Filename contains `PRINT_A4` or `PRINT_A5`
- Check `printer_log.txt` for error messages

**Solution:**
```cmd
debug_runner.bat
```
and review console output

### Issue 2: "Python not found" Error
**Solution:**
1. Reinstall Python (https://www.python.org/)
2. **Important:** Check "Add Python to PATH"
3. Restart computer
4. Re-run `install_all.bat`

### Issue 3: SumatraPDF Not Found
**Solution:**
1. Install SumatraPDF (https://www.sumatrapdfreader.org/)
2. Edit `config.json` with correct path

### Issue 4: HTML Not Converting to PDF
**Check:**
- Edge or Chrome installed
- HTML file is valid

**Solution:**
1. Install Edge or Chrome
2. Run `debug_runner.bat` for error messages

### Issue 5: Print to Different Printer
**Solution:**
1. **Tray icon** appears when app runs
2. Right-click icon → "Select Printer"

## Viewing Logs

All operations logged to `printer_log.txt`:

```cmd
type printer_log.txt
```

Or open with any text editor

## Auto-Start with Windows

Create desktop shortcut for auto-startup:

```cmd
create_desktop_shortcut.bat
```

## Uninstall

1. Run `stop_printer.bat`
2. Delete entire folder
3. Optional - Remove Python packages:
   ```cmd
   pip uninstall watchdog pystray Pillow pywin32
   ```

## Support

- Error details logged in `printer_log.txt`
- If `startup_error.txt` exists, reinstall pip packages

## System Requirements
- Windows 10/11
- Python 3.9+
- SumatraPDF (for PDF printing)
- Edge or Chrome (for HTML conversion)
