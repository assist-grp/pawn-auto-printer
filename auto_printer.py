import os
import sys
import re
import tempfile
import uuid
from pathlib import Path

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
    import queue
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
    with open(CONFIG_FILE, "r", encoding="utf-8-sig") as f:
        data = json.load(f)
        # Ensure all required keys exist with defaults
        defaults = {
            "target_printer": None,
            "kanrihyo_printer": "",
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
        # 検知と処理を分離するためのキューとワーカースレッド。
        # イベントハンドラはキューに積むだけにして即座に戻ることで、
        # 変換・印刷でブロックしている間に届く他ファイルのイベントを取りこぼさない。
        self.work_queue = queue.Queue()
        self.enqueued = set()  # 二重投入防止
        self.failed_counts = {}  # ファイルごとの印刷失敗回数
        self.max_retries = 3  # 再スキャンによる自動リトライの上限
        self._worker = threading.Thread(target=self._worker_loop, daemon=True)
        self._worker.start()

    def enqueue(self, file_path, filename):
        """ファイルを処理キューに積む（ブロックしない）。"""
        if file_path in self.processed_files or file_path in self.enqueued:
            return
        self.enqueued.add(file_path)
        self.work_queue.put((file_path, filename))

    def enqueue_new_arrival(self, file_path, filename):
        """新しく現れたファイル（作成・リネーム完了イベント）をキューに積む。
        ブラウザは削除済みファイルの名前（例: 管理票 (22).html）を再利用するため、
        同じパスが過去に「処理済み／諦め済み／起動時から存在」として記録されていても、
        新規到着なら別ファイルとして扱い、記録を消してから積む。"""
        self.processed_files.discard(file_path)
        self.failed_counts.pop(file_path, None)
        self.enqueue(file_path, filename)

    def forget_missing_files(self):
        """既に存在しないファイルの処理済み記録を捨てる。
        イベントを取りこぼした場合でも、同名で再ダウンロードされたファイルを
        定期再スキャンで拾えるようにする（記録の肥大化防止も兼ねる）。"""
        for fp in list(self.processed_files):
            if not os.path.exists(fp):
                self.processed_files.discard(fp)
                self.failed_counts.pop(fp, None)

    def _worker_loop(self):
        """キューから1件ずつ取り出し、順番に変換・印刷する専用スレッド。"""
        while True:
            file_path, filename = self.work_queue.get()
            try:
                self.process_file(file_path, filename)
            except Exception as e:
                logging.error(f"WORKER ERROR: {filename}: {e}")
            finally:
                self.enqueued.discard(file_path)
                self.work_queue.task_done()

    def seed_existing(self, directory):
        """起動時に既にあるファイルは処理済み扱いにして無視する（従来の挙動を維持）。
        再スキャンの対象を『起動後に現れたファイル』だけに限定するため。"""
        try:
            for name in os.listdir(directory):
                low = name.lower()
                if low.endswith((".html", ".pdf")):
                    self.processed_files.add(os.path.join(directory, name))
        except Exception as e:
            logging.error(f"SEED ERROR: {e}")

    def scan_existing(self, directory):
        """フォルダを定期的に再スキャンし、イベントを取りこぼした未処理ファイルを救済する。"""
        while True:
            try:
                self.forget_missing_files()
                for name in os.listdir(directory):
                    low = name.lower()
                    if low.endswith(".html.pdf"):
                        continue
                    if low.endswith((".html", ".pdf")):
                        fp = os.path.join(directory, name)
                        self.enqueue(fp, name)
            except Exception as e:
                logging.error(f"RESCAN ERROR: {e}")
            time.sleep(3)
    
    def on_created(self, event):
        if event.is_directory:
            return
        
        filename = os.path.basename(event.src_path)
        # 変換用の一時ファイル (*.html.pdf) は無視する
        if filename.lower().endswith(".html.pdf"):
            return
            
        # logging.info(f"FILE CREATED: {filename}") # Avoid spam
        if filename.lower().endswith((".pdf", ".html")):
            # キューに積むだけ（ブロックしない）→ 取りこぼし防止
            self.enqueue_new_arrival(event.src_path, filename)

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
            # キューに積むだけ（ブロックしない）→ 取りこぼし防止
            self.enqueue_new_arrival(event.dest_path, dest_filename)

    def on_modified(self, event):
        if event.is_directory:
            return
        
        filename = os.path.basename(event.src_path)
        # 変換用の一時ファイル (*.html.pdf) は無視する
        if filename.lower().endswith(".html.pdf"):
            return
        # Only process modified event if file not yet in processed or processing
        if filename.lower().endswith((".pdf", ".html")):
            file_path = event.src_path
            # Skip if already processing or processed
            if file_path in self.processed_files or file_path in self.processing_lock:
                return
            # キューに積むだけ（ブロックしない）→ 取りこぼし防止
            self.enqueue(file_path, filename)

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
        print_type = "normal"  # "normal" or "kanrihyo"
        upper_filename = filename.upper()
        
        # 管理票パターン: 管理票.pdf, 管理票(1).pdf, 管理票 (2).html など
        kanrihyo_pattern = re.compile(r'^管理票[\s\(（]?.*\.(pdf|html)$', re.IGNORECASE)
        
        if kanrihyo_pattern.match(filename):
            print_type = "kanrihyo"
            paper_size = None  # ラベルプリンター側の設定に任せる
        elif "PRINT_A4" in upper_filename:
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
            if print_type == "kanrihyo":
                logging.info(f"DETECTED: {filename} -> 管理票 (label printer)")
            else:
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
                    # 変換失敗も印刷失敗と同様にリトライ上限で打ち切る
                    # （打ち切らないと定期再スキャンで3秒ごとに変換を繰り返してしまう）
                    self.register_failure(file_path, filename)
                    return

            # PDFの印刷実行
            if self.icon:
                self.icon.notify(f"印刷を開始します: {filename}", "PDF Auto Printer")
            
            print_start = time.time()
            if print_type == "kanrihyo":
                success = self.print_pdf_kanrihyo(target_pdf)
            else:
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
                self.register_failure(file_path, filename)

        finally:
            # Always release lock
            if file_path in self.processing_lock:
                del self.processing_lock[file_path]

    def register_failure(self, file_path, filename):
        """失敗回数を数え、上限に達したら諦めて再投入を止める。
        失敗時はファイルを残すので定期再スキャンで自動リトライされるが、
        無限リトライを避けるため上限を設ける。上限到達で processed_files に入れ、
        再投入を止める（プリンター故障時などのログ溢れ防止）。"""
        count = self.failed_counts.get(file_path, 0) + 1
        self.failed_counts[file_path] = count
        if count >= self.max_retries:
            logging.error(f"PRINT FAILED (giving up after {count} tries): {filename}")
            self.processed_files.add(file_path)
            self.failed_counts.pop(file_path, None)
        else:
            logging.error(f"PRINT FAILED (attempt {count}/{self.max_retries}, will retry): {filename}")

    # 変換用HTMLの <head> 直後に差し込むスクリプト。
    # 管理票HTMLは onload で window.print() を呼ぶが、Edge 157 以降の headless
    # --print-to-pdf ではこれと衝突して PDF が生成されない（終了コードは 0 のまま）。
    # 変換時だけ print/close を無効化する。
    PRINT_GUARD_SCRIPT = b"<script>window.print=function(){};window.close=function(){};</script>"

    def make_conversion_copy(self, html_path):
        """window.print() を無効化した変換用コピーを一時フォルダに作り、そのパスを返す。
        一時ファイル名は英数字のみ（日本語パス対策）。相対パス参照が壊れないよう
        元フォルダを <base> で指定する。"""
        with open(html_path, "rb") as f:
            data = f.read()

        inject = self.PRINT_GUARD_SCRIPT
        if not re.search(rb"<base[\s>]", data, re.IGNORECASE):
            base_href = (Path(html_path).resolve().parent.as_uri() + "/").encode("utf-8")
            inject = b'<base href="' + base_href + b'">' + inject

        new_data, n = re.subn(rb"(<head[^>]*>)", lambda m: m.group(1) + inject, data, count=1, flags=re.IGNORECASE)
        if n == 0:
            new_data = inject + data

        tmp_path = os.path.join(tempfile.gettempdir(), f"pawn_print_{uuid.uuid4().hex}.html")
        with open(tmp_path, "wb") as f:
            f.write(new_data)
        return tmp_path

    def convert_html_to_pdf(self, html_path, pdf_path):
        # ブラウザのパスを探す (Edge -> Chromeの順)
        browser_path = config.get("browser_path")
        
        if not browser_path or not os.path.exists(browser_path):
            possible_paths = [
                # Edge
                r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", r"Edge\Application\msedge.exe"),
                # Chrome (Added support)
                r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Google", r"Chrome\Application\chrome.exe"),
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

        # 前回の残りがあると「PDFができたか」の判定を誤るので先に消す
        if os.path.exists(pdf_path):
            try:
                os.remove(pdf_path)
            except Exception:
                pass

        try:
            source_path = self.make_conversion_copy(html_path)
        except Exception as e:
            logging.error(f"Failed to prepare HTML for conversion: {e}")
            return False

        command = [
            browser_path,
            "--headless=new",
            "--disable-gpu",
            "--disable-software-rasterizer",
            "--disable-dev-shm-usage",
            f"--print-to-pdf={pdf_path}",
            "--no-margins",
            "--include-background",
            "--run-all-compositor-stages-before-draw",
            "--virtual-time-budget=5000",  # 描画・リソース読み込みが完了するまで待ってからPDF化（白紙対策）
            "--no-pdf-header-footer",
            Path(source_path).as_uri()
        ]

        try:
            # Reduced timeout for faster failure detection
            subprocess.run(command, check=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        except Exception as e:
            logging.error(f"Browser Conversion Error: {e}")
            return False
        finally:
            try:
                os.remove(source_path)
            except Exception:
                pass

        # ブラウザは PDF を作れなくても終了コード 0 を返すことがあるため、実物を確認する
        if not os.path.exists(pdf_path) or os.path.getsize(pdf_path) == 0:
            logging.error(f"Browser exited without creating PDF: {pdf_path}")
            return False
        return True

    def find_sumatra(self):
        """SumatraPDFのパスを検索・キャッシュする共通メソッド"""
        sumatra_path = config.get("sumatra_path")
        
        if sumatra_path and os.path.exists(sumatra_path):
            return sumatra_path
        
        # 一般的なインストール場所を検索
        possible_paths = [
            r"C:\Program Files\SumatraPDF\SumatraPDF.exe",
            r"C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe",
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "SumatraPDF", "SumatraPDF.exe"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WindowsApps", "SumatraPDF.exe"),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "SumatraPDF", "SumatraPDF.exe"),
            os.path.join(os.environ.get("PROGRAMFILES(X86)", ""), "SumatraPDF", "SumatraPDF.exe"),
            # Winget でインストールされた場所
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "SumatraPDF", "SumatraPDF.exe"),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "WindowsApps", "SumatraPDF*", "SumatraPDF.exe"),
        ]
        
        for path in possible_paths:
            if "*" in path:
                import glob
                matches = glob.glob(path)
                if matches and os.path.exists(matches[0]):
                    sumatra_path = matches[0]
                    break
            elif os.path.exists(path):
                sumatra_path = path
                break
        else:
            logging.error(f"ERROR: SumatraPDF not found. Checked locations:")
            for path in possible_paths:
                logging.error(f"  - {path}")
            logging.error("Please install SumatraPDF from: https://www.sumatrapdfreader.org/")
            return None
        
        logging.info(f"SumatraPDF found: {sumatra_path}")
        config["sumatra_path"] = sumatra_path
        save_config(config)
        return sumatra_path

    def print_pdf(self, file_path, paper_size):
        sumatra_path = self.find_sumatra()
        if not sumatra_path:
            return False

        # SumatraPDFコマンドの構築
        command = [
            sumatra_path,
            "-print-to-default" if not config.get("target_printer") else "-print-to",
        ]
        
        if config.get("target_printer"):
            command.append(config["target_printer"])
            
        command.extend([
            "-print-settings", f"paper={paper_size},fit",  # fit オプション追加（simplex は一部プリンターで paper 指定と併用すると印刷失敗するため除外）
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

    def print_pdf_kanrihyo(self, file_path):
        """管理票をラベルプリンター(Brother QL-820NWB等)で印刷"""
        kanrihyo_printer = config.get("kanrihyo_printer")
        
        if not kanrihyo_printer:
            logging.error("ERROR: kanrihyo_printer not set in config.json")
            return False
        
        sumatra_path = self.find_sumatra()
        if not sumatra_path:
            return False
        
        kanrihyo_paper_size = config.get("kanrihyo_paper_size", "")
        
        print_settings = "fit"
        if kanrihyo_paper_size:
            print_settings = f"paper={kanrihyo_paper_size},{print_settings}"
        
        command = [
            sumatra_path,
            "-print-to", kanrihyo_printer,
            "-print-settings", print_settings,
            "-silent",
            "-exit-on-print",
            file_path
        ]
        
        try:
            subprocess.run(command, check=True, timeout=30)
            return True
        except subprocess.TimeoutExpired:
            logging.error(f"KANRIHYO PRINT TIMEOUT: {file_path} (30s)")
            return False
        except subprocess.CalledProcessError as e:
            logging.error(f"KANRIHYO PRINT FAILED: {e}")
            return False

if __name__ == "__main__":
    path = config.get("watch_directory")
    if not os.path.exists(path):
        logging.error(f"ERROR: Watch directory does not exist: {path}")
        # Try default Downloads folder
        path = os.path.join(os.environ["USERPROFILE"], "Downloads")
        logging.info(f"Using default Downloads folder: {path}")

    event_handler = PDFHandler()
    # 起動時点で既にあるファイルは無視（従来挙動）。再スキャンは起動後の新規ファイルのみ救済。
    event_handler.seed_existing(path)
    observer = Observer()
    observer.schedule(event_handler, path, recursive=False)
    
    logging.info(f"Started monitoring: {path}")
    logging.info("Press Ctrl+C to stop.")
    
    observer.start()

    # 定期再スキャン: イベントを取りこぼした未処理ファイルを確実に救済する保険。
    rescan_thread = threading.Thread(target=event_handler.scan_existing, args=(path,), daemon=True)
    rescan_thread.start()

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
                    icon.notify(f"A4/A5プリンターを変更: {display_name}", "PDF Auto Printer")
                # Re-create menu to update checkmarks
                icon.menu = build_menu()
            return inner

        def set_kanrihyo_printer(printer_name):
            def inner(icon, item):
                config["kanrihyo_printer"] = printer_name
                save_config(config)
                logging.info(f"KANRIHYO PRINTER SELECTED: {printer_name}")
                if icon:
                    display_name = printer_name if printer_name else "(未設定)"
                    icon.notify(f"管理票プリンターを変更: {display_name}", "PDF Auto Printer")
                # Re-create menu to update checkmarks
                icon.menu = build_menu()
            return inner

        def build_menu():
            try:
                # Get list of printers
                printers = [p[2] for p in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
                
                # A4/A5 printer selection
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
                
                # 管理票 printer selection
                kanrihyo_items = []
                kanrihyo_items.append(MenuItem(
                    "(未設定)",
                    set_kanrihyo_printer(""),
                    checked=lambda item: not config.get("kanrihyo_printer")
                ))
                for p in printers:
                    kanrihyo_items.append(MenuItem(
                        p,
                        set_kanrihyo_printer(p),
                        checked=lambda item, p=p: config.get("kanrihyo_printer") == p
                    ))
                
                return Menu(
                    MenuItem('A4/A5 Printer', Menu(*printer_items)),
                    MenuItem('管理票 Printer', Menu(*kanrihyo_items)),
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
