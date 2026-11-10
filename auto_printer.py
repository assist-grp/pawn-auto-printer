import os
import sys
import re
import tempfile
import uuid
from pathlib import Path

# ------------------------------------------------------------
# 自動更新
# 起動時に配布元（GitHub の main ブランチ）の auto_printer.py と比べ、
# 違っていれば差し替えてから、新しいコードで起動し直す。
# watchdog などの外部パッケージより前に置き、パッケージ不足で起動できない
# 状態でも更新だけは取りに行けるようにしている。
# 更新するのはこのファイルだけ（config.json などの設定には触らない）。
# 止めたいときは config.json に "auto_update": false を書く。
# 動いている間も毎日のメンテナンス（下の「毎日のメンテナンス」）で更新を確認する。
# ------------------------------------------------------------
APP_VERSION = "2026-11-10.3"
DEFAULT_UPDATE_URL = "https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/auto_printer.py"
_UPDATED_ENV = "PAWN_AUTO_PRINTER_UPDATED"
_UPDATED_FROM_ENV = "PAWN_AUTO_PRINTER_UPDATED_FROM"
_RESUME_SINCE_ENV = "PAWN_AUTO_PRINTER_RESUME_SINCE"  # メンテナンスで起動し直したときの停止時刻
_update_messages = []  # logging の設定前に動くので、メッセージは後でまとめてログに書く


def _short_hash(data):
    import hashlib
    return hashlib.sha256(data).hexdigest()[:8]


def _download_update(url, attempts=3):
    """配布元から最新版を取得する。PC起動直後はネットワークがまだ繋がって
    いないことがあるので、接続エラーのときだけ数回やり直す。"""
    import time
    import urllib.error
    import urllib.request
    if url.startswith(("http://", "https://")):
        # GitHub の CDN キャッシュで古い版が返らないようにする
        url += ("&" if "?" in url else "?") + f"t={int(time.time())}"
    req = urllib.request.Request(url, headers={"User-Agent": "pawn-auto-printer-updater"})
    for i in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.read()
        except urllib.error.HTTPError:
            raise  # 404 などはやり直しても同じなのですぐ諦める
        except Exception:
            if i == attempts - 1:
                raise
            time.sleep(3)


def _update_settings(script_path):
    """config.json から (配布元URL, 自動更新するか) を読む。読めなければ既定値。"""
    url = DEFAULT_UPDATE_URL
    try:
        import json
        with open(os.path.join(os.path.dirname(script_path), "config.json"), encoding="utf-8-sig") as f:
            cfg = json.load(f)
        if cfg.get("auto_update") is False:
            return url, False
        url = cfg.get("update_url") or url
    except Exception:
        pass  # config.json が無い・読めない場合は既定の配布元で続ける
    return url, True


def _fetch_new_version(script_path, url, attempts=3):
    """配布元の版を取得し、手元と違えば確認済みの中身(bytes)を返す。同じなら None。
    戻り値は (新しい中身 or None, 手元の中身)。取得失敗・中身がおかしいときは例外。"""
    new_data = _download_update(url, attempts)
    with open(script_path, "rb") as f:
        old_data = f.read()
    if new_data == old_data:
        return None, old_data
    # エラーページや途中で切れたファイルで上書きしないための確認
    new_text = new_data.decode("utf-8")
    if "class PDFHandler" not in new_text or "def _self_update" not in new_text:
        raise ValueError("downloaded file does not look like auto_printer.py")
    compile(new_text, script_path, "exec")  # 文法エラーがあれば差し替えない
    return new_data, old_data


def _install_new_version(script_path, new_data):
    """確認済みの新しい版でこのファイルを置き換える（前の版は .bak に残す）。"""
    import shutil
    tmp_path = script_path + ".new"
    with open(tmp_path, "wb") as f:
        f.write(new_data)
    shutil.copy2(script_path, script_path + ".bak")  # 手で戻せるよう前の版を残す
    os.replace(tmp_path, script_path)


def _self_update():
    """手元のファイルを最新版に差し替えたら True を返す。
    取得できない・中身がおかしいなど、どんな失敗でも手元のファイルのまま起動を続ける。"""
    if os.environ.get(_UPDATED_ENV):
        return False  # 差し替え直後の起動し直し（もう一度は確認しない）
    script_path = os.path.abspath(__file__)
    url, enabled = _update_settings(script_path)
    if not enabled:
        _update_messages.append("AUTO UPDATE: disabled (config.json auto_update=false)")
        return False
    try:
        new_data, old_data = _fetch_new_version(script_path, url)
        if new_data is None:
            _update_messages.append("AUTO UPDATE: already up to date")
            return False
        _install_new_version(script_path, new_data)
        os.environ[_UPDATED_FROM_ENV] = _short_hash(old_data)
        return True
    except Exception as e:
        _update_messages.append(f"AUTO UPDATE: skipped ({e})")
        return False


if __name__ == "__main__" and _self_update():
    # 差し替えた新しいコードで、同じプロセスのまま起動し直す。
    # （別プロセスにすると start_hidden.vbs の起動確認とずれるため）
    import runpy
    os.environ[_UPDATED_ENV] = "1"
    runpy.run_path(os.path.abspath(__file__), run_name="__main__")
    sys.exit(0)

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

# 自動更新の結果と、いま動いている版をログに残す（どの版が動いているか分かるように）
for _msg in _update_messages:
    logging.info(_msg)
if os.environ.get(_UPDATED_FROM_ENV):
    logging.info(f"AUTO UPDATE: updated from sha256 {os.environ[_UPDATED_FROM_ENV]}")
try:
    with open(os.path.abspath(__file__), "rb") as _f:
        logging.info(f"VERSION: {APP_VERSION} (sha256 {_short_hash(_f.read())})")
except Exception:
    pass

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
        再スキャンの対象を『起動後に現れたファイル』だけに限定するため。
        ただしメンテナンスで起動し直した直後は、止まっていた数秒の間に届いたファイルを
        印刷対象として残す（取りこぼし防止）。"""
        since = None
        try:
            since = float(os.environ.get(_RESUME_SINCE_ENV, "")) - 5
        except ValueError:
            since = None
        try:
            for name in os.listdir(directory):
                low = name.lower()
                if low.endswith((".html", ".pdf")):
                    fp = os.path.join(directory, name)
                    if since is not None:
                        try:
                            if os.path.getmtime(fp) >= since:
                                logging.info(f"KEPT FOR PRINTING (arrived during restart): {name}")
                                continue
                        except OSError:
                            pass
                    self.processed_files.add(fp)
        except Exception as e:
            logging.error(f"SEED ERROR: {e}")

    # 印刷対象のファイル名（process_file の判定と同じ）
    KANRIHYO_PATTERN = re.compile(r'^管理票[\s\(（]?.*\.(pdf|html)$', re.IGNORECASE)

    @classmethod
    def is_print_target(cls, filename):
        if not filename.lower().endswith((".pdf", ".html")):
            return False
        upper = filename.upper()
        return bool(cls.KANRIHYO_PATTERN.match(filename)) or "PRINT_A4" in upper or "PRINT_A5" in upper

    def cleanup_old_targets(self, directory, older_than=3600):
        """印刷できずに残った印刷対象ファイル（PRINT_A4 / PRINT_A5 / 管理票、変換用の
        *.html.pdf を含む）のうち、older_than 秒より前のものを削除する。それ以外のファイルには触らない。"""
        now = time.time()
        deleted = 0
        try:
            names = os.listdir(directory)
        except OSError as e:
            logging.error(f"CLEANUP ERROR: {e}")
            return 0
        for name in names:
            if not self.is_print_target(name):
                continue
            fp = os.path.join(directory, name)
            if fp in self.processing_lock or fp in self.enqueued:
                continue
            try:
                if not os.path.isfile(fp) or now - os.path.getmtime(fp) < older_than:
                    continue
                os.remove(fp)
                deleted += 1
                self.processed_files.discard(fp)
                self.failed_counts.pop(fp, None)
                logging.info(f"CLEANUP: deleted old unprinted file: {name}")
            except OSError as e:
                logging.error(f"CLEANUP: could not delete {name}: {e}")
        return deleted

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


# ------------------------------------------------------------
# 毎日のメンテナンス（スリープで使い続けるPC向け）
# 起動時の自動更新だけだと、スリープで使い続けるPCには修正が届かない。
# 毎日 maintenance_time（config.json、既定 20:00）に、
#   1. 印刷できずに残った古いファイル（PRINT_A4 / PRINT_A5 / 管理票）の片付け
#   2. 配布元の確認。新しい版があれば、印刷していないときに起動し直す
# を行う。スリープ中でも、タスクスケジューラのスリープ解除タイマーでPCを起こす。
# 起こせなかった（電源設定でスリープ解除タイマーが無効など）ときは、次にPCが起きたときに行う。
# ------------------------------------------------------------
WAKE_TASK_NAME = "PDFAutoPrinterWake"
MAINTENANCE_TICK = 30          # 見回りの間隔（秒）
IDLE_SECONDS = 120             # 監視フォルダに直近2分間動きがないときだけ起動し直す
KEEP_AWAKE_LIMIT = 15 * 60     # メンテナンス中にPCを起こしておく上限（秒）
CLEANUP_OLDER_THAN = 3600      # 片付けるのは1時間より前のファイルだけ
UPDATE_RETRY_DELAY = 120       # スリープ解除直後はネットワークがつながっていないことがあるので、失敗したら2分後に再確認
UPDATE_RETRY_MAX = 3


def _maintenance_time():
    """config.json の maintenance_time（"HH:MM"）。おかしければ 20:00。"""
    value = str(config.get("maintenance_time") or "20:00")
    try:
        hh, mm = (int(x) for x in value.split(":"))
        if 0 <= hh < 24 and 0 <= mm < 60:
            return hh, mm
    except ValueError:
        pass
    logging.error(f"MAINTENANCE: invalid maintenance_time {value!r}; using 20:00")
    return 20, 0


def _next_maintenance_after(ts, hh, mm):
    """時刻 ts より後で最初に来る hh:mm（ローカル時刻）のタイムスタンプ。"""
    import datetime
    base = datetime.datetime.fromtimestamp(ts)
    target = base.replace(hour=hh, minute=mm, second=0, microsecond=0)
    if target <= base:
        target += datetime.timedelta(days=1)
    return target.timestamp()


def _keep_awake(on):
    """メンテナンス中にPCがまたスリープしないようにする（Windows のみ。同じスレッドから解除する）。"""
    if os.name != "nt":
        return
    try:
        import ctypes
        ES_CONTINUOUS, ES_SYSTEM_REQUIRED = 0x80000000, 0x00000001
        ctypes.windll.kernel32.SetThreadExecutionState(ES_CONTINUOUS | (ES_SYSTEM_REQUIRED if on else 0))
    except Exception:
        pass


def _register_wake_task(hh, mm):
    """毎日 hh:mm に、スリープ中でもPCを起こすタスク（このユーザー用）を登録する。
    実行するのは start_hidden.vbs（アプリが動いていれば何もしない。止まっていれば起動する）。
    アプリのフォルダを移しても、起動のたびに今の場所で登録し直す。"""
    if os.name != "nt":
        return
    vbs = os.path.join(os.path.dirname(os.path.abspath(__file__)), "start_hidden.vbs")

    def q(s):
        return "'" + s.replace("'", "''") + "'"

    ps = (
        f"$a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument {q(chr(34) + vbs + chr(34))}; "
        f"$t = New-ScheduledTaskTrigger -Daily -At {q(f'{hh:02d}:{mm:02d}')}; "
        "$s = New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-ExecutionTimeLimit (New-TimeSpan -Minutes 5); "
        f"Register-ScheduledTask -TaskName {q(WAKE_TASK_NAME)} -Action $a -Trigger $t -Settings $s "
        "-Description 'PDF Auto Printer: wake the PC for the daily update check and cleanup' -Force | Out-Null"
    )
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", ps],
            capture_output=True, text=True, errors="replace", timeout=60,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        if r.returncode == 0:
            logging.info(f"MAINTENANCE: wake task '{WAKE_TASK_NAME}' set for {hh:02d}:{mm:02d} every day")
        else:
            logging.error(f"MAINTENANCE: could not set the wake task: {(r.stderr or r.stdout).strip()[:300]}")
    except Exception as e:
        logging.error(f"MAINTENANCE: could not set the wake task: {e}")


def _watch_dir_is_quiet(directory, seconds):
    """監視フォルダに、直近 seconds 秒以内に変更されたファイルが無いか（ダウンロード中・直後でないか）。"""
    now = time.time()
    try:
        names = os.listdir(directory)
    except OSError:
        return True
    for name in names:
        try:
            age = now - os.path.getmtime(os.path.join(directory, name))
        except OSError:
            continue
        if 0 <= age < seconds:
            return False
    return True


def _restart_with_new_version(handler, old_hash):
    """新しい版で起動し直す。いつもの起動と同じ start_hidden.vbs を使うため、このプロセスが
    終わってから起動されるよう、5秒待って start_hidden.vbs を実行する小さな補助プロセスを残して終了する。"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    vbs = os.path.join(script_dir, "start_hidden.vbs")
    env = dict(os.environ)
    env.pop(_UPDATED_ENV, None)
    env[_UPDATED_FROM_ENV] = old_hash
    env[_RESUME_SINCE_ENV] = str(time.time())  # 止まっている間に届いたファイルを新しいプロセスで印刷する
    code = ("import subprocess, sys, time; time.sleep(5); "
            "subprocess.Popen(['wscript.exe', sys.argv[1]], cwd=sys.argv[2])")
    flags = (subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP) if os.name == "nt" else 0
    subprocess.Popen([sys.executable, "-c", code, vbs, script_dir], env=env, cwd=script_dir,
                     creationflags=flags, close_fds=True)
    logging.info("MAINTENANCE: restarting the app with the new version")
    try:
        if handler.icon:
            handler.icon.stop()
            time.sleep(1)
    except Exception:
        pass
    logging.shutdown()
    os._exit(0)


# ------------------------------------------------------------
# 状況報告（どのPCに最新版が入っているか把握するため）
# 起動時と毎日のメンテナンスのときに、Googleフォームへ PC名・版・場所・自動更新の可否を送る。
# 回答はフォームにつながったスプレッドシートに1行ずつたまる（「PCごとの最新」シートでPCごとの最新を表示）。
# 送るだけで、失敗しても印刷には影響しない。止めたいときは config.json に "report": false を書く。
# ------------------------------------------------------------
REPORT_URL = "https://docs.google.com/forms/d/e/1FAIpQLSfwQ9uz_AaEjB6PFyYTU-6F-frkjNttrp_ujNBrtW9smdFdnQ/formResponse"
REPORT_FIELDS = {
    "pc": "entry.1798885157",           # PC名
    "version": "entry.809843841",       # バージョン
    "place": "entry.715387568",         # 場所
    "auto_update": "entry.119468854",   # 自動更新
}
REPORT_RETRY_DELAY = 60   # 起動直後はネットワークがまだ繋がっていないことがあるので、失敗したら1分後に再送
REPORT_RETRY_MAX = 5


def _auto_update_status(script_dir):
    """自動更新できる状態か（設定で止めていないか、フォルダに書き込めるか）。"""
    _url, enabled = _update_settings(os.path.join(script_dir, "auto_printer.py"))
    if not enabled:
        return "無効 (auto_update=false)"
    probe = os.path.join(script_dir, f"write_test_{uuid.uuid4().hex}.tmp")
    try:
        with open(probe, "w") as f:
            f.write("x")
        os.remove(probe)
        return "OK"
    except OSError:
        return "NG (フォルダに書き込めない)"


def send_status_report(trigger):
    """状況を1回送る。成功したら True。"""
    script_path = os.path.abspath(__file__)
    script_dir = os.path.dirname(script_path)
    try:
        with open(script_path, "rb") as f:
            digest = _short_hash(f.read())
    except OSError:
        digest = "?"
    data = {
        REPORT_FIELDS["pc"]: f"{os.environ.get('COMPUTERNAME', '?')} ({os.environ.get('USERNAME', '?')})",
        REPORT_FIELDS["version"]: f"{APP_VERSION} (sha256 {digest})",
        REPORT_FIELDS["place"]: script_dir,
        REPORT_FIELDS["auto_update"]: _auto_update_status(script_dir),
    }
    url = config.get("report_url") or REPORT_URL
    try:
        import urllib.parse
        import urllib.request
        req = urllib.request.Request(
            url, data=urllib.parse.urlencode(data).encode("utf-8"),
            headers={"User-Agent": "pawn-auto-printer-report",
                     "Content-Type": "application/x-www-form-urlencoded; charset=utf-8"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp.read(1)
        logging.info(f"REPORT: sent ({trigger})")
        return True
    except Exception as e:
        logging.info(f"REPORT: not sent ({trigger}): {e}")
        return False


def report_in_background(trigger):
    """印刷を止めないよう別スレッドで送る。失敗したら少し待って数回やり直す。"""
    if config.get("report", True) is False:
        return

    def run():
        for i in range(REPORT_RETRY_MAX):
            if send_status_report(trigger):
                return
            time.sleep(REPORT_RETRY_DELAY)

    threading.Thread(target=run, daemon=True).start()


def maintenance_loop(handler, watch_dir):
    script_path = os.path.abspath(__file__)
    hh, mm = _maintenance_time()
    if config.get("maintenance_wake", True) is not False:
        _register_wake_task(hh, mm)
    next_due = _next_maintenance_after(time.time(), hh, mm)
    check_at = None      # 更新を確認する時刻（失敗したら少し後にやり直す）
    check_tries = 0
    pending = None       # 見つかった新しい版 (中身, 今の版のハッシュ)。印刷していないときに入れ替える
    awake_since = None

    def release_awake():
        nonlocal awake_since
        if awake_since is not None:
            _keep_awake(False)
            awake_since = None

    while True:
        time.sleep(MAINTENANCE_TICK)
        try:
            now = time.time()
            # 1. メンテナンス開始（時刻を過ぎていたら。スリープ明けで遅れた場合もここで行う）
            if now >= next_due and pending is None and check_at is None:
                late = now - next_due
                note = "" if late < 600 else f" (late by {int(late // 60)} min: the PC was asleep or off)"
                logging.info(f"MAINTENANCE: start{note}")
                _keep_awake(True)
                awake_since = now
                report_in_background("maintenance")
                if config.get("maintenance_cleanup", True) is not False:
                    n = handler.cleanup_old_targets(watch_dir, CLEANUP_OLDER_THAN)
                    logging.info(f"MAINTENANCE: cleanup deleted {n} old unprinted file(s)")
                next_due = _next_maintenance_after(now, hh, mm)
                url, enabled = _update_settings(script_path)
                if enabled:
                    check_at, check_tries = now, 0
                else:
                    logging.info("MAINTENANCE: auto update is disabled (config.json auto_update=false)")

            # 2. 更新の確認
            if check_at is not None and now >= check_at:
                url, _enabled = _update_settings(script_path)
                try:
                    new_data, old_data = _fetch_new_version(script_path, url)
                    check_at = None
                    if new_data is None:
                        logging.info("MAINTENANCE: already up to date")
                    else:
                        pending = (new_data, _short_hash(old_data))
                        logging.info(f"MAINTENANCE: new version found (sha256 {_short_hash(new_data)}); "
                                     "the app restarts when nothing is being printed")
                except Exception as e:
                    check_tries += 1
                    if check_tries < UPDATE_RETRY_MAX:
                        check_at = now + UPDATE_RETRY_DELAY
                        logging.info(f"MAINTENANCE: update check failed ({e}); retry in {UPDATE_RETRY_DELAY // 60} min")
                    else:
                        check_at = None
                        logging.info(f"MAINTENANCE: update check skipped ({e}); next try at the next maintenance")

            # 3. 新しい版への入れ替え（印刷していない・ダウンロードもない時だけ）
            if pending is not None:
                if awake_since is not None and now - awake_since > KEEP_AWAKE_LIMIT:
                    release_awake()  # PCを起こしておくのはここまで。入れ替えは暇になったときに続ける
                busy = handler.work_queue.unfinished_tasks > 0 or bool(handler.processing_lock)
                if busy or not _watch_dir_is_quiet(watch_dir, IDLE_SECONDS):
                    continue
                new_data, old_hash = pending
                try:
                    _install_new_version(script_path, new_data)
                except Exception as e:
                    logging.error(f"MAINTENANCE: could not install the new version ({e}); "
                                  "will try again at the next maintenance")
                    pending = None
                    release_awake()
                    continue
                _restart_with_new_version(handler, old_hash)

            if check_at is None and pending is None:
                release_awake()
        except Exception as e:
            logging.error(f"MAINTENANCE ERROR: {e}")


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

    # 毎日のメンテナンス（片付け・更新の確認。スリープ中ならPCを起こす）
    maintenance_thread = threading.Thread(target=maintenance_loop, args=(event_handler, path), daemon=True)
    maintenance_thread.start()

    # 状況報告（どのPCが最新版か把握するため。失敗しても印刷には影響しない）
    report_in_background("startup")

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
