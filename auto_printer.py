import os
import time
import json
import subprocess
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import threading
from PIL import Image
from pystray import Icon, Menu, MenuItem
import win32print

# 設定の読み込み
CONFIG_FILE = "config.json"

def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {
            "watch_directory": os.path.join(os.environ["USERPROFILE"], "Downloads"),
            "sumatra_path": r"C:\Program Files\SumatraPDF\SumatraPDF.exe",
            "log_file": "printer_log.txt",
            "target_printer": None
        }
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
        if "target_printer" not in data:
            data["target_printer"] = None
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
    
    def on_created(self, event):
        if event.is_directory:
            return
        
        filename = os.path.basename(event.src_path)
        # 変換用の一時ファイル (*.html.pdf) は無視する
        if filename.lower().endswith(".html.pdf"):
            return
            
        logging.info(f"FILE CREATED: {filename}")
        if filename.lower().endswith((".pdf", ".html")):
            # 待機時間をさらに短縮 (0.5s -> 0.1s)
            time.sleep(0.1)
            self.process_file(event.src_path, filename)
    
    def on_moved(self, event):
        """Handle file rename/move events (e.g., .tmp -> .pdf/html)"""
        if event.is_directory:
            return
        
        dest_filename = os.path.basename(event.dest_path)
        # 変換用の一時ファイル (*.html.pdf) は無視する
        if dest_filename.lower().endswith(".html.pdf"):
            return
            
        logging.info(f"FILE MOVED/RENAMED: {os.path.basename(event.src_path)} -> {dest_filename}")
        
        if dest_filename.lower().endswith((".pdf", ".html")):
            # 待機時間をさらに短縮 (0.5s -> 0.1s)
            time.sleep(0.1)
            self.process_file(event.dest_path, dest_filename)
    
    def on_modified(self, event):
        if event.is_directory:
            return
        
        filename = os.path.basename(event.src_path)
        if filename.lower().endswith((".pdf", ".html")):
            # Modified events fire multiple times, so we skip them
            # to avoid duplicate printing
            pass

    def process_file(self, file_path, filename):
        # Avoid processing the same file multiple times
        if file_path in self.processed_files:
            logging.info(f"ALREADY PROCESSED: {filename}")
            return
        
        # Check if file is currently being processed
        if file_path in self.processing_lock:
            logging.info(f"CURRENTLY PROCESSING: {filename}")
            return
        
        # Check if file still exists
        if not os.path.exists(file_path):
            logging.info(f"FILE NO LONGER EXISTS: {filename}")
            return
        
        # Mark as being processed
        self.processing_lock[file_path] = True
        self.processed_files.add(file_path)
        
        paper_size = None
        
        # Match filenames (Case-insensitive)
        upper_filename = filename.upper()
        if "PRINT_A4" in upper_filename:
            paper_size = "A4"
        elif "PRINT_A5" in upper_filename:
            paper_size = "A5"
        
        if paper_size:
            logging.info(f"DETECTED: {filename} -> Target paper size {paper_size}")
            
            target_pdf = file_path
            is_html = filename.lower().endswith(".html")
            
            # HTMLの場合はPDFに変換
            if is_html:
                temp_pdf = file_path + ".pdf"
                logging.info(f"CONVERTING HTML TO PDF: {filename}")
                if self.convert_html_to_pdf(file_path, temp_pdf):
                    target_pdf = temp_pdf
                else:
                    logging.error(f"CONVERSION FAILED: {filename}")
                    if file_path in self.processing_lock: del self.processing_lock[file_path]
                    return

            # PDFの印刷実行
            success = self.print_pdf(target_pdf, paper_size)
            
            if success:
                # 印刷成功後、元のファイルを削除
                try:
                    if os.path.exists(file_path):
                        os.remove(file_path)
                        logging.info(f"ORIGINAL FILE DELETED: {file_path}")
                        # 削除に成功したら、processed_filesからも削除する（再ダウンロード時に印刷できるようにするため）
                        if file_path in self.processed_files:
                            self.processed_files.remove(file_path)
                except Exception as e:
                    logging.error(f"Failed to delete original file: {e}")
                
                # HTMLから作成した一時PDFも削除
                if is_html and os.path.exists(target_pdf):
                    try:
                        os.remove(target_pdf)
                        logging.info(f"TEMP PDF DELETED: {target_pdf}")
                    except Exception as e:
                        logging.error(f"Failed to delete temp pdf: {e}")
        else:
            logging.info(f"SKIPPED: {filename} (filename does not match)")
            # マッチしなかった場合もロックと処理済みリストから外す（将来的に同じ名前のファイルが来る可能性があるため）
            if file_path in self.processed_files:
                self.processed_files.remove(file_path)
        
        # Remove from processing lock
        if file_path in self.processing_lock:
            del self.processing_lock[file_path]

    def convert_html_to_pdf(self, html_path, pdf_path):
        edge_path = config.get("edge_path", r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
        
        # Edgeのパスを探す
        if not os.path.exists(edge_path):
            possible_paths = [
                r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Edge\Application\msedge.exe"),
            ]
            for p in possible_paths:
                if os.path.exists(p):
                    edge_path = p
                    break
            else:
                logging.error("ERROR: Microsoft Edge not found.")
                return False

        command = [
            edge_path,
            "--headless=new",
            "--disable-gpu",
            f"--print-to-pdf={pdf_path}",
            "--no-margins",
            "--include-background",
            "--run-all-compositor-stages-before-draw",
            "--virtual-time-budget=2000",  # 5sから2sに短縮（これ以上短いとCSSが反映されない可能性あり）
            f"file:///{os.path.abspath(html_path).replace('\\', '/')}"
        ]
        
        try:
            subprocess.run(command, check=True, timeout=60)
            return True
        except Exception as e:
            logging.error(f"Edge Conversion Error: {e}")
            return False

    def print_pdf(self, file_path, paper_size):
        sumatra_path = config.get("sumatra_path")
        
        # SumatraPDFのパスを探す
        if not os.path.exists(sumatra_path):
            # 一般的なインストール場所を検索
            possible_paths = [
                r"C:\Program Files\SumatraPDF\SumatraPDF.exe",
                r"C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WindowsApps", "SumatraPDF.exe"),
            ]
            
            for path in possible_paths:
                if os.path.exists(path):
                    sumatra_path = path
                    logging.info(f"SumatraPDF found: {sumatra_path}")
                    break
            else:
                logging.error(f"ERROR: SumatraPDF not found. Checked locations:")
                for path in possible_paths:
                    logging.error(f"  - {path}")
                return False

        # SumatraPDFコマンドの構築
        command = [
            sumatra_path,
            "-print-to-default" if not config.get("target_printer") else "-print-to",
        ]
        
        if config.get("target_printer"):
            command.append(config["target_printer"])
            
        command.extend([
            "-print-settings", f"paper={paper_size},simplex",
            "-silent",
            file_path
        ])

        try:
            subprocess.run(command, check=True)
            logging.info(f"PRINT SUCCESS: {file_path}")
            return True
        except subprocess.CalledProcessError as e:
            logging.error(f"PRINT FAILED: {e}")
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
        icon_path = "app_icon.png"
        
        def set_printer(printer_name):
            def inner(icon, item):
                config["target_printer"] = printer_name
                save_config(config)
                logging.info(f"PRINTER SELECTED: {printer_name}")
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
