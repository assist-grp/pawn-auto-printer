# Pawn Auto Printer - Windows インストールガイド

> **このガイドについて**
> パソコンが苦手な方でも進められるよう、順番に説明します。上から1つずつ進めてください。
> インストールが終わったあとの**プリンター設定や使い方**は、別の **[STAFF_GUIDE_JP.md](STAFF_GUIDE_JP.md)（スタッフ向けガイド）** を見てください。

---

## はじめに：用意するもの・かかる時間

- **インターネット接続**（必要なソフトをダウンロードします）
- **管理者の権限**（インストールには管理者として実行が必要です）
- 時間の目安：**10〜20分**

### このアプリでやること（全体の流れ）

1. アプリに必要なソフト（Python・SumatraPDF・部品）を入れる
2. アプリを起動して、パソコン起動時に自動で立ち上がるようにする
3. プリンターを選ぶ（→ スタッフ向けガイド）

---

## ステップ 1：必要なソフトを入れる

2つのやり方があります。**まずは「方法A」を試し、止まったり失敗したら「方法B」**に進んでください。

### 方法A：自動インストール（ワンクリック）

1. `install_all.bat` を**右クリック** →「**管理者として実行**」を選ぶ
   - ※ ダブルクリックではなく「右クリック →管理者として実行」が確実です
2. 「このアプリがデバイスに変更を加えることを許可しますか？」と出たら「**はい**」
3. 黒い画面でインストールが進みます。完了まで**数分**待ちます

> **うまくいかないとき**（よくあります）：
> 画面が「99%」や途中で**止まったまま動かない**、エラーが出る場合は、無理せず**方法B**に進んでください。原因のほとんどは Windows の `winget` という仕組みの不調です。詳しくは「トラブルシューティング 問題2／2-2」を参照。

### 方法B：手動インストール（確実）

`winget` を使わないので、**いちばん確実**です。順番にやってください。

**① Python を入れる**
1. ブラウザで https://www.python.org/downloads/ を開く
2. 「Download Python」をクリックしてダウンロード
3. ダウンロードしたファイルを実行
4. 最初の画面の**いちばん下の「Add python.exe to PATH」に必ずチェック**を入れる ← これが最重要
5. 「Install Now」を押して、完了まで待つ

**② SumatraPDF を入れる**（PDFの印刷に使います）
1. https://www.sumatrapdfreader.org/download-free-pdf-viewer を開く
2. 「**64-bit Installer**」をダウンロードして実行

**③ 部品（ライブラリ）を入れる**
1. スタートメニューで「**PowerShell**」を開く（黒い画面が出ます）
2. 次の1行をコピーして貼り付け、Enter（**フォルダ移動は不要**）：
   py -m pip install pywin32 pystray watchdog Pillow
3. 「Successfully installed」または「already satisfied」と出れば成功です

---

## ステップ 2：アプリを起動する

`start_hidden.vbs` を**ダブルクリック**します。
画面右下のタスクトレイ（時計の近く）に**アプリのアイコンが出れば成功**です（黒い画面は出ません）。

> 📷 _画像を入れる場所：タスクトレイのアイコン_
> `![トレイアイコン](images/tray_icon.png)`

アイコンが出ない／エラーが出る場合は、`debug_runner.bat` をダブルクリックすると、原因のメッセージが表示されます（トラブルシューティング参照）。

---

## ステップ 3：パソコン起動時に自動で立ち上げる

詳しくは下の「**Windows スタートアップに自動登録**」を参照してください。いちばん確実なのは `register_autostart.bat` を**右クリック →「管理者として実行」**する方法です。

---

## ステップ 4：プリンターを選ぶ（使い始める設定）

ここまでできたら、**[STAFF_GUIDE_JP.md](STAFF_GUIDE_JP.md)（スタッフ向けガイド）** の「プリンターの設定」を見て、印刷先のプリンターを選んでください。トレイアイコンを右クリックするだけで設定できます。

---

## 日常的な使用方法

### バックグラウンド起動（推奨）
- `start_background.bat` をダブルクリック → 非表示で実行開始

### デバッグモード（トラブル対応）
- `debug_runner.bat` をダブルクリック → コンソール表示で実行

### 実行停止
- `stop_printer.bat` をダブルクリック

## ファイル形式

### PDFを印刷
- ファイル名に `PRINT_A4` または `PRINT_A5` を含める
- 例: `document_PRINT_A4.pdf`

### HTMLを変換して印刷
- `.html` ファイルを監視フォルダに置く
- ファイル名に `PRINT_A4` または `PRINT_A5` を含める
- 例: `report_PRINT_A5.html` → 自動的に PDF に変換して印刷

## トラブルシューティング

### 問題 1: ファイルが印刷されない
**確認事項：**
- ファイル名に `PRINT_A4` または `PRINT_A5` が含まれているか
- `printer_log.txt` にエラーメッセージがないか確認

**解決方法：**
```cmd
debug_runner.bat
```
で実行して、コンソール出力を確認

### 問題 2: "Python not found" エラー / winget で Python が入らない

`install_all.bat` 実行中に以下のように表示されて止まる場合、winget が古いか Python パッケージを取得できていません：
```
Python not found or broken (Stub detected). Attempting install via winget...
入力条件に一致するパッケージが見つかりませんでした。
```

**解決方法：Python を python.org から直接インストール（最も確実）**

`install_all.bat` は最初に PATH 上の Python を探すため、手動で入れれば winget のステップは自動でスキップされます。

1. https://www.python.org/downloads/ にアクセスし、最新版（Python 3.9 以上）をダウンロード
2. ダウンロードしたインストーラを実行
3. 最初の画面の **一番下にある「Add python.exe to PATH」に必ずチェック**を入れる（最重要）
4. 「Install Now」をクリックしてインストール完了まで待つ
5. インストール後、`install_all.bat` を **右クリック →「管理者として実行」** で再実行
6. 残り（SumatraPDF・Python ライブラリ・自動起動）が自動で続行されます

**確認方法：** コマンドプロンプトで以下を実行し、バージョンが表示されれば成功
```cmd
python --version
```

**補足：winget を直して使いたい場合**

PowerShell（管理者）で以下を実行してから `install_all.bat` を再実行：
```powershell
winget source reset --force
winget source update
```
それでも「パッケージが見つかりません」と出る場合は、Microsoft Store で「アプリ インストーラー」を更新してください（winget 本体が古いため）。

### 問題 2-2: install_all.bat が途中で止まる / winget が固まる

`install_all.bat` 実行中、以下のような所で進まなくなることがあります（winget のハング）。環境によって起きやすく、待っても解消しないことがあります。

- 進捗バーが「`█████ 99%`」のまま動かない
- 「利用可能なアップグレードが見つかりませんでした」の後で止まる
- 「Step 3」や「Step 4」の手前で固まる

**まず2〜3分待つ** → それでも全く動かなければ、以下の手順で対応します。

**対応：画面を閉じて手動で仕上げる（確実）**

`install_all.bat` がやることは「Python・SumatraPDF・ライブラリのインストール」と「自動起動登録」だけです。固まった時点で Python や SumatraPDF が既に入っていれば、残りは手動で完了できます。

1. 固まったウィンドウを「×」で閉じる
2. **ライブラリをインストール**（PowerShell を開き、フォルダ移動は不要）：
   ```powershell
   py -m pip install pywin32 pystray watchdog Pillow
   ```
   「Successfully installed」または「already satisfied」が出ればOK
3. **Python / SumatraPDF が未インストールなら手動で**：
   - Python: https://www.python.org/downloads/ →「Add python.exe to PATH」にチェックしてインストール
   - SumatraPDF: https://www.sumatrapdfreader.org/ から 64-bit Installer
4. **アプリを起動**：`start_hidden.vbs` をダブルクリック → トレイにアイコンが出ればOK
5. **自動起動を登録**：「Windows スタートアップに自動登録」の項を参照

> **ヒント：** winget は環境によって不安定です。最初から `install_all.bat` を使わず、上記の「Python 手動インストール → `py -m pip install ...` → SumatraPDF 手動インストール」の順で進めると、winget のトラブルを完全に回避できます。

### 問題 2-3: ファイル（auto_printer.py / install.ps1 / start_hidden.vbs）が消える

インストール後にアプリが起動しない場合、`auto_printer.py` などの重要ファイルが**ウイルス対策ソフトに削除・隔離されている**ことがあります（フォルダ監視・自動印刷・ファイル削除を行うため、誤検知されやすい）。

**症状の例：**
- `install_all.bat` が「`-File 'install.ps1' は存在しません`」で止まる
- `start_hidden.vbs` ダブルクリックで「Could not start... python process keeps crashing」
- `py auto_printer.py` で「No such file or directory」

**解決方法：**

1. **フォルダを除外設定に追加（最重要・先に実施）**
   - Windows セキュリティ →「ウイルスと脅威の防止」→「設定の管理」→「除外」→「除外の追加」→「フォルダー」
   - アプリのインストールフォルダ（`...\dev\pawn-auto-printer`）を指定
2. **消えたファイルを復元**
   - Windows セキュリティ →「保護の履歴」から該当ファイルを「許可」「復元」
   - または正常なPC・元の配布データから該当ファイルをコピーし直す
3. `dir`（または エクスプローラー）で `auto_printer.py` が存在することを確認してから起動

> 除外設定を**先に**行わないと、復元してもまた削除されます。

### 問題 3: SumatraPDF が見つからない
**解決方法：**
1. SumatraPDF をインストール（https://www.sumatrapdfreader.org/）
2. `config.json` を編集して、正しいパスを設定

### 問題 4: HTMLが PDF に変換されない
**確認事項：**
- Edge または Chrome がインストールされているか
- HTML ファイルが正しい形式か

**解決方法：**
1. Edge または Chrome をインストール
2. `debug_runner.bat` でエラーメッセージを確認

### 問題 5: 異なるプリンターで印刷したい
**解決方法：**
1. アプリ起動時に**トレイアイコン**が表示される
2. アイコンをクリック → 「Select Printer」でプリンター選択

## ログの確認

すべての処理は `printer_log.txt` に記録されます：

```cmd
type printer_log.txt
```

または、ファイルをテキストエディタで開いて確認

## Windows スタートアップに自動登録

通常は `install_all.bat` のインストール時に自動登録されます。

### 再起動してもアプリが自動で立ち上がらない場合（推奨：確実な方法）

タスクスケジューラに登録する方法です。`shell:startup` が開けない、デスクトップが OneDrive に移動されている等の環境でも確実に動作します。

1. `register_autostart.bat` を **右クリック →「管理者として実行」**
2. 「SUCCESS - Auto-start registered.」と表示されれば完了（その場でアプリも起動します）
3. PC を再起動し、タスクトレイにアイコンが出れば成功

確認・解除コマンド（コマンドプロンプト）：
```cmd
schtasks /Query /TN "PDFAutoPrinter"     :: 登録状態を確認
schtasks /Delete /TN "PDFAutoPrinter" /F :: 自動起動を解除
```

### 手動でスタートアップフォルダに登録する場合

1. エクスプローラーのアドレスバーに以下を貼り付けて Enter
   ```
   %AppData%\Microsoft\Windows\Start Menu\Programs\Startup
   ```
2. インストールフォルダの `start_hidden.vbs` を右クリック →「コピー」
3. 開いたスタートアップフォルダ内で右クリック →「**ショートカットの貼り付け**」

### デスクトップにアイコンを作る場合（任意）

```cmd
create_desktop_shortcut.bat
```
※ デスクトップが OneDrive に移動されている環境ではエラーになることがあります。その場合は `start_hidden.vbs` を右クリック →「送る」→「デスクトップ（ショートカットを作成）」で作成してください。

### 自動起動しないときの切り分け

1. `start_background.bat` で手動起動できるか確認
   - 起動する → アプリは正常。自動起動の登録のみが問題 → 上記「確実な方法」で再登録
   - 起動しない → `verify_installation.bat` で Python・ライブラリ・SumatraPDF の不足を確認、`debug_runner.bat` でエラー内容を確認

## アンインストール

1. `stop_printer.bat` で実行を停止
2. フォルダ全体を削除
3. Python パッケージを削除（オプション）：
   ```cmd
   pip uninstall watchdog pystray Pillow pywin32
   ```

## サポート

- `printer_log.txt` にエラーの詳細が記録されます
- `startup_error.txt` がある場合は、pip パッケージのインストールをやり直してください

## その他

### システム要件
- Windows 10/11
- Python 3.9 以上
- SumatraPDF （PDF 印刷用）
- Edge または Chrome （HTML 変換用）

### オプション設定
`config.json` の例：
```json
{
    "watch_directory": "C:/Users/user/Downloads",
    "sumatra_path": "C:/Program Files/SumatraPDF/SumatraPDF.exe",
    "browser_path": "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
    "log_file": "printer_log.txt",
    "target_printer": "Canon Pixma",
    "auto_delete": true
}
```
