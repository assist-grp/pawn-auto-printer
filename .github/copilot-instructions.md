# Pawn Auto Printer - AI Agent Instructions

## Project Overview
A Windows-based automatic PDF/HTML printing system that monitors a folder, detects documents with paper size markers in filenames, converts HTML to PDF via browser, and prints using SumatraPDF. Designed for unattended operation with system tray interface.

## Architecture

### Core Components
- **PDFHandler (watchdog)**: File system event listener watching for `.pdf` and `.html` files
- **Processing Pipeline**: 
  1. Detect paper size from filename markers (`PRINT_A4`, `PRINT_A5`)
  2. Convert HTML→PDF using browser headless mode (Edge/Chrome priority)
  3. Print via SumatraPDF with detected paper size
  4. Clean up original files after successful print
- **System Tray UI**: Icon menu for printer selection, runs in main thread

### Configuration System
- Single `config.json` with keys: `watch_directory`, `sumatra_path`, `browser_path`, `log_file`, `target_printer`, `auto_delete`
- Dynamically discovers browser and SumatraPDF paths on first run
- Paths persisted to config for subsequent launches

## Key Patterns & Conventions

### Duplicate Prevention
Two-layer deduplication in `PDFHandler`:
- `processed_files` set: Tracks successfully printed files; prevents reprocessing
- `processing_lock` dict: Prevents concurrent processing of same file
- Non-matching files added to `processed_files` immediately (marked IGNORED)

### File State Management
- **Ready Check** (`is_file_ready()`): Validates file size > 0 and readable before processing
- **Locked Files**: Return False from `is_file_ready()` to defer processing; watchdog events retry
- **Cleanup**: Original HTML and temporary `.html.pdf` deleted after successful print, then removed from `processed_files` to allow same-name reprocessing

### Browser HTML-to-PDF Conversion
- Tries Edge first, falls back to Chrome: `--headless=new --print-to-pdf` with `--no-margins` and `--include-background`
- File path converted to URL format: `file:///C:/path` (forward slashes required)
- Timeout: 60 seconds
- Error handling: Returns False on subprocess failure; file not marked as processed (implicit retry on next modification event)

### Printer Selection
- Dynamic enumeration via `win32print.EnumPrinters()` 
- Menu checkmarks show current selection (lambda with closure captures printer name)
- None value means system default printer
- Tray icon notifications in Japanese

## Development Workflows

### Installation & Setup (Windows)
**Critical:** Windows 10/11 only. Python 3.9+ required.

1. **Automated Setup** (Recommended)
   - Run `install_all.bat` as Administrator
   - Automatically: discovers Python, installs SumatraPDF, installs pip packages, creates startup shortcut

2. **Verification**
   - After install: run `verify_installation.bat` to validate all dependencies
   - Checks Python, pip packages, SumatraPDF, Edge/Chrome availability
   - Shows ✓ for working items, ⚠ for optional/missing, ✗ for failures

3. **Configuration**
   - Edit `config.json` with paths and preferences
   - Key fields: `watch_directory` (folder to monitor), `sumatra_path`, `target_printer` (None = default)

### Running the Application

- **Interactive**: `run_printer.bat` (shows console, good for initial testing)
- **Background**: `start_background.bat` (uses pythonw, no console window)
- **Debug**: `debug_runner.bat` (console output for troubleshooting)
- **Stop**: `stop_printer.bat` (kills process)
- **Auto-start**: `create_desktop_shortcut.bat` (registers in Windows Startup folder)

### Testing
- `debug_runner.bat`: Runs with console output for troubleshooting
- `check_status.bat`: Verifies running processes and log status
- `trace_installer.bat`: Diagnostic batch for dependency issues
- Logs written to `printer_log.txt` (UTF-8 encoding, ASCII fallback for hard errors)

### Startup Modes
- **Interactive**: `auto_printer.py` directly (for development)
- **Background**: `start_background.bat` (Python subprocess, hides window)
- **Hidden VBS**: `start_hidden.vbs` (Windows Script Host wrapper)
- **Desktop Shortcut**: `create_desktop_shortcut.bat` adds Start Menu entry

### Installation Guide
- See `INSTALL_JP.md` (Japanese) or `INSTALL_EN.md` (English)
- Both include step-by-step setup, troubleshooting, file format rules

## Project-Specific Conventions

### Logging
- Use `log_info()` wrapper for safe encoding; catches and retries with ASCII fallback
- INFO level for startup, processing milestones; ERROR for failures
- Filenames logged with direction: "DETECTED", "PROCESSING", "IGNORED", "PRINT SUCCESS"

### Filename Rules
- **Paper Size Detection** (case-insensitive): `PRINT_A4` or `PRINT_A5` required in filename
- HTML files converted before print (no direct HTML printing)
- Temporary files `*.html.pdf` explicitly ignored in event handler (prevents feedback loops)

### Error Handling
- **Missing Browser/SumatraPDF**: Gracefully discover from common Windows paths; log checked locations
- **File Locked**: Defer (watchdog retries on modification)
- **Conversion/Print Failure**: Log error, release lock, retry if file modified again (not marked processed)
- **Tray Icon Missing**: App continues without UI (fallback loop)
- **Import Errors**: Write `startup_error.txt` with pip install instructions and exit (see lines 9-19)

## External Dependencies
- **watchdog**: File system monitoring (OS events)
- **SumatraPDF**: Printing engine (detected at `C:\Program Files\...`)
- **Edge/Chrome**: HTML-to-PDF rendering (headless CLI)
- **pywin32**: Printer enumeration for tray menu
- **PIL (Pillow)**: Tray icon image loading

## Integration Points
- **Event Loop**: Watchdog observer runs in background thread; tray icon runs in main thread (some OS require this)
- **Process Communication**: All external tools (browser, SumatraPDF, win32print) called via `subprocess.run()`
- **File System**: Monitors only non-recursive events in configured directory; uses absolute paths throughout

## Common Debugging Scenarios
1. **File not printing**: Check filename contains `PRINT_A4` or `PRINT_A5`; verify SumatraPDF path in config
2. **HTML not converting**: Verify Edge/Chrome installed; check `printer_log.txt` for browser path discovery
3. **Duplicate prints**: Inspect `processed_files` set handling; ensure file wasn't immediately redownloaded
4. **Tray menu empty**: `win32print.EnumPrinters()` may timeout; see error in logs
