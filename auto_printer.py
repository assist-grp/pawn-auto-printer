import os
import sys

# DEBUG: Catch import errors immediately
missing_packages = []
try:
    import time
    import json
    import subprocess
    import logging
except ImportError as e:
    missing_packages.append(str(e))

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
except ImportError as e:
    missing_packages.append("watchdog")

try:
    import threading
except ImportError as e:
    missing_packages.append("threading")

try:
    from PIL import Image
except ImportError as e:
    missing_packages.append("Pillow")

try:
    from pystray import Icon, Menu, MenuItem
except ImportError as e:
    missing_packages.append("pystray")

try:
    import win32print
except ImportError as e:
    missing_packages.append("pywin32")

if missing_packages:
    error_msg = f"CRITICAL ERROR: Missing Python packages.\n\n"
    error_msg += f"Missing: {', '.join(set(missing_packages))}\n\n"
    error_msg += "Please run this command as Administrator:\n"
    error_msg += f"python -m pip install {' '.join(set(missing_packages))}\n\n"
    error_msg += "Or try:\n"
    error_msg += f"py -m pip install {' '.join(set(missing_packages))}\n"
    
    with open("startup_error.txt", "w", encoding="utf-8") as f:
        f.write(error_msg)
    
    print(error_msg)
    input("Press Enter to exit...")
    sys.exit(1)

# 設定の読み込み
CONFIG_FILE = "config.json"

def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {
            "watch_directory": os.path.join(os.environ["USERPROFILE"], "Downloads"),
            "sumatra_path": "",
            "browser_path": "",
            "log_file": "printer_log.txt",
            "target_printer": None,
            "auto_delete": True
        }
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
        # Ensure all required keys exist with defaults
        defaults = {
            "target_printer": None,
            "auto_delete": True,
            "sumatra_path": "",
            "browser_path": "",
            "watch_directory": os.path.join(os.environ["USERPROFILE"], "Downloads")
        }
        for key, default_value in defaults.items():
            if key not in data:
                data[key] = default_value
        return data

def save_config(new_config):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(new_config, f, indent=4, ensure_ascii=False)

config = load_config()

# ログの設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    handlers=[
        logging.FileHandler(config.get("log_file", "printer_log.txt"), encoding='utf-8'),
        logging.StreamHandler()
    ]
)

def log_info(message):
    """Log message in ASCII to avoid encoding issues"""
    try:
        logging.info(message)
    except:
        # Fallback to ASCII-only
        logging.info(message.encode('ascii', 'replace').decode('ascii'))

class PDFHandler(FileSystemEventHandler):
    def __init__(self):
        super().__init__()
        self.processed_files = set()  # Track processed files to avoid duplicates
        self.processing_lock = {}  # Lock to prevent concurrent processing
        self.icon = None  # Reference to tray icon for notifications
    
    def on_created(self, event):
        if event.is_directory:
            return
        
        filename = os.path.basename(event.src_path)
        # 変換用の一時ファイル (*.html.pdf) は無視する
        if filename.lower().endswith(".html.pdf"):
            return
            
        # logging.info(f"FILE CREATED: {filename}") # Avoid spam
        if filename.lower().endswith((".pdf", ".html")):
            # Remove sleep for instant reaction
            # time.sleep(0.1) 
            self.process_file(event.src_path, filename)
    
    def on_moved(self, event):
        """Handle file rename/move events (e.g., .tmp -> .pdf/html)"""
        if event.is_directory:
            return
        
        dest_filename = os.path.basename(event.dest_path)
        # 変換用の一時ファイル (*.html.pdf) は無視する
        if dest_filename.lower().endswith(".html.pdf"):
            return
            
        logging.info(f"FILE MOVED: {os.path.basename(event.src_path)} -> {dest_filename}")
        
        if dest_filename.lower().endswith((".pdf", ".html")):
            # Remove sleep for instant reaction
            # time.sleep(0.1)
            self.process_file(event.dest_path, dest_filename)
    
    def on_modified(self, event):
        if event.is_directory:
            return
        
        filename = os.path.basename(event.src_path)
        # Only process modified event if file not yet in processed or processing
        if filename.lower().endswith((".pdf", ".html")):
            file_path = event.src_path
            # Skip if already processing or processed
            if file_path in self.processed_files or file_path in self.processing_lock:
                return
            self.process_file(file_path, filename)

    def is_file_ready(self, file_path, max_wait=1.0):
        """Check if file is readable and not empty with minimal wait"""
        start_time = time.time()
        while time.time() - start_time < max_wait:
            try:
                size = os.path.getsize(file_path)
                if size == 0:
                    time.sleep(0.1)
                    continue
                # Quick read test
                with open(file_path, 'rb') as f:
                    f.read(1)
                return True
            except Exception:
                time.sleep(0.05)
        return False

    def process_file(self, file_path, filename):
        start_time = time.time()
        
        # Avoid processing the same file multiple times (if already successfully printed)
        if file_path in self.processed_files:
            return
        
        # Check if file is currently being processed
        if file_path in self.processing_lock:
            return
        
        # Check if file still exists
        if not os.path.exists(file_path):
            return
            
        # Check matching rules FIRST before locking
        paper_size = None
        upper_filename = filename.upper()
        if "PRINT_A4" in upper_filename:
            paper_size = "A4"
        elif "PRINT_A5" in upper_filename:
            paper_size = "A5"
        else:
            # Not a target file, mark as processed to ignore future events
            self.processed_files.add(file_path)
            logging.info(f"IGNORED: {filename}")
            return

        # Check if file is ready (not locked, has content)
        ready_start = time.time()
        if not self.is_file_ready(file_path):
            return
        ready_time = time.time() - ready_start
        
        # Mark as being processed
        self.processing_lock[file_path] = True
        logging.info(f"PROCESSING: {filename} (ready check: {ready_time:.2f}s)")
        
        try:
            logging.info(f"DETECTED: {filename} -> Target paper size {paper_size}")
            
            target_pdf = file_path
            is_html = filename.lower().endswith(".html")
            
            # HTMLの場合はPDFに変換
            if is_html:
                temp_pdf = file_path + ".pdf"
                convert_start = time.time()
                logging.info(f"CONVERTING HTML TO PDF: {filename}")
                if self.convert_html_to_pdf(file_path, temp_pdf):
                    target_pdf = temp_pdf
                    convert_time = time.time() - convert_start
                    logging.info(f"CONVERSION COMPLETE: {filename} ({convert_time:.2f}s)")
                else:
                    logging.error(f"CONVERSION FAILED: {filename}")
                    return

            # PDFの印刷実行
            if self.icon:
                self.icon.notify(f"印刷を開始します: {filename}", "PDF Auto Printer")
            
            print_start = time.time()
            success = self.print_pdf(target_pdf, paper_size)
            print_time = time.time() - print_start
            
            if success:
                total_time = time.time() - start_time
                logging.info(f"PRINT SUCCESS: {filename} (print: {print_time:.2f}s, total: {total_time:.2f}s)")
                
                # Mark as successfully processed ONLY after print
                self.processed_files.add(file_path)
                
                if self.icon:
                    self.icon.notify(f"印刷完了: {filename}", "PDF Auto Printer")
                # 印刷成功後、元のファイルを削除
                try:
                    if os.path.exists(file_path):
                        os.remove(file_path)
                        logging.info(f"ORIGINAL FILE DELETED: {file_path}")
                        # 削除したらprocessed_filesからも消す（万が一同名ファイルが即座に来た場合のため）
                        # ただし、OSがイベントを後追いで送ってくる可能性もあるので、
                        # 少し残しておきたいが... 削除されたらイベントは来ないのでOK。
                        if file_path in self.processed_files:
                            self.processed_files.remove(file_path)
                except Exception as e:
                    logging.error(f"Failed to delete original file: {e}")
                
                # HTMLから作成した一時PDFも削除
                if is_html and os.path.exists(target_pdf):
                    try:
                        os.remove(target_pdf)
                    except Exception:
                        pass
            else:
                logging.error(f"PRINT FAILED: {filename}")
                # Don't add to processed_files, so it might retry if modified?
                # Or adds risk of infinite loop if printer is broken.
                # But for locked files vs printer errors, we should distinguish.
                # Here we assume printer error is transient or file specific.
        
        finally:
            # Always release lock
            if file_path in self.processing_lock:
                del self.processing_lock[file_path]

    def preprocess_html(self, html_path):
        """外部リソース（fonts.googleapis.com, debugbar等）のリンクを削除して高速化"""
        try:
            with open(html_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_len = len(content)
            import re
            # 外部フォントのlinkタグを削除（改行を含む場合も対応: re.DOTALL）
            content = re.sub(r'<link[^>]*href=["\'][^"\']*fonts\.googleapis\.com[^"\']*["\'][^>]*>', '', content, flags=re.IGNORECASE | re.DOTALL)
            # fonts.googleapis.comがURLに改行を含む場合（https:\n//fonts...）
            content = re.sub(r'<link[^>]*href=["\']https?:\s*//fonts\.googleapis\.com[^"\']*["\'][^>]*>', '', content, flags=re.IGNORECASE | re.DOTALL)
            # 外部CSSのlinkタグを削除（fonts.gstatic.com, fontawesome等）
            content = re.sub(r'<link[^>]*href=["\'][^"\']*fonts\.gstatic\.com[^"\']*["\'][^>]*>', '', content, flags=re.IGNORECASE | re.DOTALL)
            content = re.sub(r'<link[^>]*href=["\'][^"\']*fontawesome[^"\']*["\'][^>]*>', '', content, flags=re.IGNORECASE | re.DOTALL)
            # @import url(...)も削除
            content = re.sub(r'@import\s+url\([^)]*fonts\.googleapis\.com[^)]*\);?', '', content, flags=re.IGNORECASE | re.DOTALL)
            content = re.sub(r'@import\s+url\([^)]*fontawesome[^)]*\);?', '', content, flags=re.IGNORECASE | re.DOTALL)
            
            # DebugBar関連を削除（開発用なので本番印刷には不要）
            content = re.sub(r'<link[^>]*href=["\']?[^"\']*_debugbar[^"\']*["\']?[^>]*>', '', content, flags=re.IGNORECASE | re.DOTALL)
            content = re.sub(r'<script[^>]*src=["\']?[^"\']*_debugbar[^"\']*["\']?[^>]*></script>', '', content, flags=re.IGNORECASE | re.DOTALL)
            content = re.sub(r'<script[^>]*>jQuery\.noConflict\(true\);</script>', '', content, flags=re.IGNORECASE | re.DOTALL)
            
            # CSS内のNunitoフォント参照をシステムフォントに置換（外部フォント読み込みを防止）
            content = re.sub(r'font-family:\s*Nunito\s*,', 'font-family:system-ui,', content, flags=re.IGNORECASE)
            content = re.sub(r"font-family:\s*'Nunito'\s*,", 'font-family:system-ui,', content, flags=re.IGNORECASE)
            content = re.sub(r'font-family:\s*"Nunito"\s*,', 'font-family:system-ui,', content, flags=re.IGNORECASE)
            
            removed_bytes = original_len - len(content)
            
            # 前処理済みファイルを一時保存
            preprocessed_path = html_path + ".preprocessed.html"
            with open(preprocessed_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            logging.info(f"PREPROCESSED: {os.path.basename(html_path)} (removed {removed_bytes} bytes of external resources)")
            return preprocessed_path
        except Exception as e:
            logging.error(f"HTML Preprocess Error: {e}")
            return html_path  # 失敗時は元ファイルを使用

    def convert_html_to_pdf(self, html_path, pdf_path):
        # 前処理: 外部リソースを削除
        preprocessed_path = self.preprocess_html(html_path)
        
        # ブラウザのパスを探す (Edge -> Chromeの順)
        browser_path = config.get("browser_path")
        
        if not browser_path or not os.path.exists(browser_path):
            possible_paths = [
                # Edge
                r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Edge\Application\msedge.exe"),
                # Chrome (Added support)
                r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Google", "Chrome\Application\chrome.exe"),
            ]
            for p in possible_paths:
                if os.path.exists(p):
                    browser_path = p
                    logging.info(f"Browser found: {browser_path}")
                    break
            else:
                logging.error(f"ERROR: No compatible browser (Edge/Chrome) found.")
                return False
        
        # Save found browser to config for next time
        if browser_path != config.get("browser_path"):
            config["browser_path"] = browser_path
            save_config(config)

        # 固定のユーザーデータディレクトリを使用（プロファイル作成を回避して高速化）
        user_data_dir = os.path.join(os.environ.get("TEMP", "C:\\Temp"), "pawn_printer_browser")
        cache_dir = os.path.join(os.environ.get("TEMP", "C:\\Temp"), "pawn_printer_cache")
        
        command = [
            browser_path,
            "--headless=new",
            f"--user-data-dir={user_data_dir}",
            f"--disk-cache-dir={cache_dir}",
            "--disk-cache-size=104857600",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-software-rasterizer",
            "--disable-dev-shm-usage",
            "--disable-extensions",
            "--disable-plugins",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-sync",
            "--disable-translate",
            "--disable-component-update",
            "--disable-background-networking",
            "--disable-client-side-phishing-detection",
            "--disable-default-apps",
            "--disable-hang-monitor",
            "--disable-popup-blocking",
            "--disable-prompt-on-repost",
            "--metrics-recording-only",
            "--safebrowsing-disable-auto-update",
            f"--print-to-pdf={pdf_path}",
            "--no-margins",
            "--include-background",
            "--no-pdf-header-footer",
            f"file:///{os.path.abspath(preprocessed_path).replace('\\', '/')}"
        ]
        
        try:
            subprocess.run(command, check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            # 前処理ファイルを削除
            if preprocessed_path != html_path and os.path.exists(preprocessed_path):
                try:
                    os.remove(preprocessed_path)
                except:
                    pass
            return True
        except Exception as e:
            logging.error(f"Browser Conversion Error: {e}")
            # エラー時も前処理ファイルを削除
            if preprocessed_path != html_path and os.path.exists(preprocessed_path):
                try:
                    os.remove(preprocessed_path)
                except:
                    pass
            return False

    def print_pdf(self, file_path, paper_size):
        sumatra_path = config.get("sumatra_path")
        
        # SumatraPDFのパスを探す
        if not sumatra_path or not os.path.exists(sumatra_path):
            # 一般的なインストール場所を検索
            possible_paths = [
                r"C:\Program Files\SumatraPDF\SumatraPDF.exe",
                r"C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "SumatraPDF", "SumatraPDF.exe"),
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WindowsApps", "SumatraPDF.exe"),
                os.path.join(os.environ.get("PROGRAMFILES", ""), "SumatraPDF", "SumatraPDF.exe"),
                os.path.join(os.environ.get("PROGRAMFILES(X86)", ""), "SumatraPDF", "SumatraPDF.exe"),
            ]
            
            # Winget でインストールされた場所を追加検索
            winget_paths = [
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "SumatraPDF", "SumatraPDF.exe"),
                os.path.join(os.environ.get("PROGRAMFILES", ""), "WindowsApps", "SumatraPDF*", "SumatraPDF.exe"),
            ]
            possible_paths.extend(winget_paths)
            
            for path in possible_paths:
                # ワイルドカード対応
                if "*" in path:
                    import glob
                    matches = glob.glob(path)
                    if matches and os.path.exists(matches[0]):
                        sumatra_path = matches[0]
                        logging.info(f"SumatraPDF found: {sumatra_path}")
                        # 設定に保存
                        config["sumatra_path"] = sumatra_path
                        save_config(config)
                        break
                elif os.path.exists(path):
                    sumatra_path = path
                    logging.info(f"SumatraPDF found: {sumatra_path}")
                    # 設定に保存
                    config["sumatra_path"] = sumatra_path
                    save_config(config)
                    break
            else:
                logging.error(f"ERROR: SumatraPDF not found. Checked locations:")
                for path in possible_paths:
                    logging.error(f"  - {path}")
                logging.error("Please install SumatraPDF from: https://www.sumatrapdfreader.org/")
                return False

        # SumatraPDFコマンドの構築
        command = [
            sumatra_path,
            "-print-to-default" if not config.get("target_printer") else "-print-to",
        ]
        
        if config.get("target_printer"):
            command.append(config["target_printer"])
            
        command.extend([
            "-print-settings", f"paper={paper_size},simplex,fit",  # fit オプション追加
            "-silent",
            "-exit-on-print",  # 印刷後すぐに終了（待機時間削減）
            file_path
        ])

        try:
            # タイムアウト追加で長時間ハングを防止
            subprocess.run(command, check=True, timeout=30)
            return True
        except subprocess.TimeoutExpired:
            logging.error(f"PRINT TIMEOUT: {file_path} (30s)")
            return False
        except subprocess.CalledProcessError as e:
            logging.error(f"PRINT FAILED: {e}")
            return False
            return False

if __name__ == "__main__":
    path = config.get("watch_directory")
    if not os.path.exists(path):
        logging.error(f"ERROR: Watch directory does not exist: {path}")
        # Try default Downloads folder
        path = os.path.join(os.environ["USERPROFILE"], "Downloads")
        logging.info(f"Using default Downloads folder: {path}")

    event_handler = PDFHandler()
    observer = Observer()
    observer.schedule(event_handler, path, recursive=False)
    
    logging.info(f"Started monitoring: {path}")
    logging.info("Press Ctrl+C to stop.")
    
    observer.start()

    # System Tray Icon Setup
    def quit_app(icon, item):
        logging.info("Stopping observer...")
        observer.stop()
        icon.stop()

    def create_tray_icon():
        # Use PNG for tray icon (better transparency)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(script_dir, "app_icon.png")
        
        def set_printer(printer_name):
            def inner(icon, item):
                config["target_printer"] = printer_name
                save_config(config)
                logging.info(f"PRINTER SELECTED: {printer_name}")
                if icon:
                    display_name = printer_name if printer_name else "Default Printer"
                    icon.notify(f"プリンターを変更しました: {display_name}", "PDF Auto Printer")
                # Re-create menu to update checkmarks
                icon.menu = build_menu()
            return inner

        def build_menu():
            try:
                # Get list of printers
                printers = [p[2] for p in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
                
                printer_items = []
                # Default option
                printer_items.append(MenuItem(
                    "Default Printer", 
                    set_printer(None), 
                    checked=lambda item: config.get("target_printer") is None
                ))
                
                # List of printers
                for p in printers:
                    printer_items.append(MenuItem(
                        p, 
                        set_printer(p), 
                        checked=lambda item, p=p: config.get("target_printer") == p
                    ))
                
                return Menu(
                    MenuItem('Select Printer', Menu(*printer_items)),
                    Menu.SEPARATOR,
                    MenuItem('Quit', quit_app)
                )
            except Exception as e:
                logging.error(f"Failed to build printer menu: {e}")
                return Menu(MenuItem('Quit', quit_app))

        if os.path.exists(icon_path):
            try:
                image = Image.open(icon_path)
                icon = Icon("PDFAutoPrinter", image, "PDF Auto Printer", build_menu())
                event_handler.icon = icon  # Give handler access to icon for notifications
                icon.run()
            except Exception as e:
                logging.error(f"Failed to load tray icon: {e}")
                # Keep running without tray icon if loading fails
                while observer.is_alive():
                    time.sleep(1)
        else:
            logging.warning("app_icon.png not found, running without tray icon.")
            while observer.is_alive():
                time.sleep(1)

    try:
        # Start tray icon in main thread (some OS require this)
        # Observer is already running in its own thread
        create_tray_icon()
    except KeyboardInterrupt:
        observer.stop()
    
    observer.join()
