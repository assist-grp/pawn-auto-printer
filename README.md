# Pawn Auto Printer

**自動 PDF/HTML 印刷システム** - Windows での無人運用向け

質札（PRINT_A4 / PRINT_A5）や管理票（ラベル）を、ダウンロードフォルダに入るだけで**自動で印刷**します。パソコン起動時に自動で立ち上がり、裏で待機します。

---

## 📚 ドキュメント（まずはここ）

| 目的 | ドキュメント |
|---|---|
| **インストールしたい**（初心者向け・手順つき） | [INSTALL_JP.md](INSTALL_JP.md) |
| **設定・毎日の使い方**（スタッフ向け） | [STAFF_GUIDE_JP.md](STAFF_GUIDE_JP.md) |
| トラブル対応 | [INSTALL_JP.md](INSTALL_JP.md) の「トラブルシューティング」 / [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| ユーザーマニュアル | [0_Manual_JP.html](0_Manual_JP.html) |
| English | [INSTALL_EN.md](INSTALL_EN.md) |

---

## 🚀 クイックスタート

### 1. インストール（1回だけ）

zip は**「ドキュメント」フォルダの中**に展開します（例：`C:\Users\（ユーザー名）\Documents\pawn-auto-printer`）。自動更新のため、管理者権限なしで書き込める場所に置く必要があります（`Program Files` やダウンロードフォルダには置かないでください）。

`install_all.bat` を **右クリック →「管理者として実行」**。Python・SumatraPDF・必要な部品を自動でインストールします。

> ⚠️ `install_all.bat` が途中で止まる／エラーになる場合は `winget` の不調です。その場合は **手動インストール**（Python を python.org から、`py -m pip install pywin32 pystray watchdog Pillow`、SumatraPDF を公式サイトから）が確実です。詳細は [INSTALL_JP.md](INSTALL_JP.md)。

### 2. 起動

`start_hidden.vbs` を**ダブルクリック** → タスクトレイにアイコンが出れば動作中です（画面は出ません）。

### 3. パソコン起動時に自動で立ち上げる

`register_autostart.bat` を **右クリック →「管理者として実行」**（最も確実）。

### 4. プリンターを選ぶ

タスクトレイのアイコンを**右クリック**して、印刷先プリンターを選びます（→ [STAFF_GUIDE_JP.md](STAFF_GUIDE_JP.md)）。**config.json を手で編集する必要はありません。**

---

## 📄 使用方法

監視フォルダ（通常はダウンロードフォルダ）に入ったファイルのうち、**ファイル名で印刷対象が決まります**：

```
✓ report_PRINT_A4.pdf        → PDF を A4 で印刷
✓ invoice_PRINT_A5.html      → HTML を PDF に変換して A5 で印刷
✓ 管理票.html                → ラベルプリンターで印刷（管理票）
✗ document.pdf               → 無視される（マーカーなし）
```

| ファイル名 | 印刷先 |
|---|---|
| `…PRINT_A4….pdf` / `.html` | A4/A5 プリンター（A4） |
| `…PRINT_A5….pdf` / `.html` | A4/A5 プリンター（A5） |
| `管理票….html` / `.pdf` | 管理票プリンター（ラベル） |

---

## ✨ 特徴

✅ **完全自動化** - ファイルが入るだけで印刷
✅ **複数用紙サイズ** - A4/A5 を自動選択
✅ **管理票（ラベル）対応** - QL-820NWB などのラベルプリンターに対応
✅ **HTML 対応** - Edge/Chrome で自動変換
✅ **プリンター選択** - トレイメニューから簡単切り替え（A4/A5 用・管理票用を個別に）
✅ **連続印刷に強い** - 複数ファイルが同時に来ても取りこぼさない（キュー処理＋定期再スキャン）
✅ **無人運用** - バックグラウンド実行・起動時自動立ち上げ
✅ **自動更新** - 起動のたびに最新版の `auto_printer.py` を取得（各PCでの差し替え作業が不要）

---

## ⚙️ 管理コマンド（.bat / .vbs）

| ファイル | 説明 |
|---------|------|
| `install_all.bat` | インストール（管理者として実行） |
| `start_hidden.vbs` | 起動（非表示・推奨） |
| `start_background.bat` | 起動（バックグラウンド） |
| `debug_runner.bat` | デバッグ起動（コンソールにエラー表示） |
| `register_autostart.bat` | 起動時の自動立ち上げを登録（管理者として実行） |
| `create_desktop_shortcut.bat` | デスクトップに手動起動用アイコンを作成 |
| `verify_installation.bat` | インストール状態の確認 |
| `stop_printer.bat` | 停止 |

> アプリの**終了**は、トレイアイコンを右クリック →「Quit」が確実です。

---

## 📋 システム要件

- **Windows 10/11**
- **Python 3.9 以上**
- **SumatraPDF**（PDF 印刷用）
- **Edge または Chrome**（HTML 変換用）

---

## 🔧 設定（config.json）

プリンターの選択は**トレイメニューで行うのが基本**です（手編集不要）。以下は必要な場合のみ編集します（**保存は UTF-8**）：

```json
{
    "watch_directory": "監視フォルダ（空ならダウンロードフォルダ）",
    "sumatra_path": "SumatraPDF のパス（空なら自動検出）",
    "browser_path": "Edge/Chrome のパス（空なら自動検出）",
    "target_printer": "質札用プリンター（通常はトレイで設定）",
    "kanrihyo_printer": "管理票用プリンター（通常はトレイで設定）",
    "kanrihyo_paper_size": "管理票の用紙サイズ（例: 62mm）",
    "auto_delete": true,
    "auto_update": true
}
```

`auto_update` は省略時 `true`（自動更新する）。止めたい PC だけ `false` にします。

設定を変えたら、アプリを再起動（トレイ →「Quit」→ `start_hidden.vbs`）すると反映されます。

---

## 📝 ログ確認

すべての処理は `printer_log.txt`（インストールフォルダ内）に記録されます。トラブル時はこのファイルを確認してください。

起動時には動いている版が `VERSION: 2026-11-10 (sha256 xxxxxxxx)` の形で、自動更新の結果が `AUTO UPDATE: …` の形で記録されます。

---

## 🔄 自動更新

アプリは起動のたびに、GitHub の `main` ブランチにある `auto_printer.py` と手元のファイルを比べ、違っていれば差し替えてから新しい版で起動します。

- アプリは管理者権限なしで動くので、**アプリのフォルダに管理者権限なしで書き込めることが必要**です（`C:\Program Files (x86)` の下は通常不可。新しく入れるときは「ドキュメント」フォルダの中に置きます）
- 更新されるのは `auto_printer.py` だけです。`config.json`（プリンター設定）などには触りません
- 取得できない・中身が壊れているなどの場合は差し替えず、今の版のまま起動します
- 差し替え前の版は `auto_printer.py.bak` に残ります（戻すときはこれを `auto_printer.py` にリネーム）
- PC を再起動しない限り更新されません。すぐ反映したいときはトレイ →「Quit」→ `start_hidden.vbs`

### 手動で今すぐ更新する（自動更新が入る前の古い版の PC も、これで更新できます）

PowerShell を開き、**どのフォルダからでも**次の1行を貼り付けます（アプリのフォルダへ移動する必要はありません）：

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/update.ps1 | iex
```

[update.ps1](update.ps1) がアプリのフォルダを自動で探し（動いているアプリ → タスクスケジューラ「PDFAutoPrinter」→ スタートアップ／デスクトップのショートカット → 見つからなければディスクを検索）、`auto_printer.py` を最新版に差し替え、そのフォルダに管理者権限なしで書き込めるか（＝自動更新できるか）を確認してから、アプリを再起動します。最後に `VERSION: …` の行が表示されれば完了です。

- 管理者ではない普通の PowerShell で実行してください（管理者だと書き込み確認ができません）
- `[WARN] auto-update CANNOT write to this folder` と出たら、そのフォルダでは自動更新できません。下の移動コマンドで「ドキュメント」フォルダの中へ移してください（Program Files のPCはそのまま運用し、更新したいときは「管理者として実行」の PowerShell で更新コマンドを実行）
- アプリを動かしている Windows ユーザーでサインインして実行してください（別ユーザーのアプリは見つけられません）
- 再起動の瞬間にダウンロード中のファイルは印刷されないことがあるので、印刷していないときに実行してください

### アプリを「ドキュメント」フォルダへ移す

ダウンロードフォルダなどに置いてしまったアプリは、次の1行で「ドキュメント」フォルダの `pawn-auto-printer` へ移せます（普通の PowerShell で、どのフォルダからでも実行可）：

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/assist-grp/pawn-auto-printer/main/move_to_documents.ps1 | iex
```

[move_to_documents.ps1](move_to_documents.ps1) はアプリを止めてフォルダごと（`config.json` も）コピーし、スタートアップ／デスクトップのショートカット・タスク「PDFAutoPrinter」・Windows Defender の除外設定を新しい場所に合わせます（後の2つのために管理者の確認が1回出ます）。新しい場所で起動を確認できたら、古いフォルダを削除します。アプリが Program Files にある場合や、すでに「ドキュメント」にある場合は何もしません。

---

## ⚠️ 注意事項

- ファイル名に `PRINT_A4` / `PRINT_A5`、または `管理票…` の指定が必要です（それ以外は無視）
- HTML ファイルは自動的に PDF に変換してから印刷します
- **フォルダの場所を移動する場合**は、移動後に自動起動ショートカット（スタートアップ）とデスクトップショートカットを作り直してください。`config.json` を引き継げばプリンター設定は保持されます
- ファイルが消える／起動しない場合は、ウイルス対策ソフトの誤検知が原因のことがあります（[INSTALL_JP.md](INSTALL_JP.md) の「問題 2-3」参照）

---

## 🔧 開発者向け

### Mac で Windows 配布用 ZIP を作成

```bash
./create_release_zip.sh
```

生成される `pawn-auto-printer.zip` を Windows に転送して使用します。

### 修正を各PCに配る

`auto_printer.py` を `main` に push すると、各PCの次回起動時に自動で反映されます（リポジトリは公開設定が前提）。

- push する前に、文法エラーがないことを確認してください（`python3 -m py_compile auto_printer.py`）。文法エラーのある版は各PCが受け取らずに無視しますが、動作がおかしい版はそのまま配られます
- 版の目印として、変更時は `auto_printer.py` 先頭の `APP_VERSION` を更新してください

---

**更新日:** 2026年11月10日
