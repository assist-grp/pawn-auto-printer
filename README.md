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
    "auto_delete": true
}
```

設定を変えたら、アプリを再起動（トレイ →「Quit」→ `start_hidden.vbs`）すると反映されます。

---

## 📝 ログ確認

すべての処理は `printer_log.txt`（インストールフォルダ内）に記録されます。トラブル時はこのファイルを確認してください。

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

---

**更新日:** 2026年6月25日
