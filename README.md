# Pawn Auto Printer

**自動 PDF/HTML 印刷システム** - Windows での無人運用向け

## 🚀 クイックスタート

### 1. インストール（1回だけ）

```cmd
install_all.bat
```

管理者権限で実行してください。自動的に：
- Python 3.9+ のインストール確認
- SumatraPDF のダウンロード
- 必要な Python パッケージをインストール
- 初期設定ファイルを作成

### 2. 設定

`config.json` をテキストエディタで開いて、以下を設定：

```json
{
    "watch_directory": "C:/Users/YourName/Downloads",
    "sumatra_path": "C:/Program Files/SumatraPDF/SumatraPDF.exe",
    "log_file": "printer_log.txt",
    "auto_delete": true
}
```

### 3. 起動

```cmd
run_printer.bat                    # コンソール表示で実行
```

または

```cmd
start_background.bat               # バックグラウンド実行（推奨）
```

## 📄 使用方法

監視フォルダに PDF または HTML ファイルを置き、**ファイル名に用紙サイズを指定**：

```
✓ report_PRINT_A4.pdf        → PDF を A4 で印刷
✓ invoice_PRINT_A5.html      → HTML を PDF に変換して A5 で印刷
✗ document.pdf               → 無視される（マーカーなし）
```

**対応用紙サイズ:** `PRINT_A4` / `PRINT_A5`（大文字・小文字の区別なし）

## 🛠️ トラブルシューティング

### インストール検証

```cmd
verify_installation.bat
```

### デバッグモード

```cmd
debug_runner.bat
```

### ステータス確認

```cmd
check_status.bat
```

### 詳細ガイド

- **日本語:** [INSTALL_JP.md](INSTALL_JP.md)
- **English:** [INSTALL_EN.md](INSTALL_EN.md)
- **トラブル対応:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## ⚙️ 管理コマンド

| コマンド | 説明 |
|---------|------|
| `run_printer.bat` | 起動（コンソール表示） |
| `start_background.bat` | 起動（バックグラウンド） |
| `debug_runner.bat` | デバッグモード |
| `stop_printer.bat` | 停止 |
| `check_status.bat` | ステータス確認 |
| `verify_installation.bat` | インストール検証 |
| `create_desktop_shortcut.bat` | Windows 起動時に自動実行 |

## 📋 システム要件

- **Windows 10/11**
- **Python 3.9+**
- **SumatraPDF**（PDF 印刷用）
- **Edge または Chrome**（HTML 変換用）

## 📖 ドキュメント

- **インストールガイド（日本語）:** [INSTALL_JP.md](INSTALL_JP.md)
- **インストールガイド（English）:** [INSTALL_EN.md](INSTALL_EN.md)
- **トラブルシューティング:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **ユーザー マニュアル:** [0_Manual_JP.html](0_Manual_JP.html)
- **AI コーディング ガイド:** [.github/copilot-instructions.md](.github/copilot-instructions.md)

## 🔧 詳細設定

`config.json` で以下も設定可能：

```json
{
    "watch_directory": "監視フォルダ",
    "sumatra_path": "SumatraPDF のパス",
    "browser_path": "Edge/Chrome のパス（自動検出）",
    "log_file": "ログファイル名",
    "target_printer": "プリンター名（null=デフォルト）",
    "auto_delete": true
}
```

## 📝 ログ確認

```cmd
type printer_log.txt
```

## ✨ 特徴

✅ **完全自動化** - ファイルを置くだけで印刷  
✅ **複数用紙サイズ** - A4/A5 を自動選択  
✅ **HTML 対応** - Edge/Chrome で自動変換  
✅ **プリンター選択** - トレイメニューから簡単切り替え  
✅ **無人運用** - バックグラウンド実行対応  

## ⚠️ 注意事項

- 初回起動時に依存ツール（SumatraPDF など）の自動検出・ダウンロードが行われます
- ファイル名に `PRINT_A4` / `PRINT_A5` の指定は必須です
- HTML ファイルは自動的に PDF に変換してから印刷します
- **フォルダの場所:** アプリは解凍したフォルダで動作します。フォルダを移動する場合は、必ず移動後に `create_desktop_shortcut.bat` を再実行してください

---

## 🔧 開発者向け

### Mac で Windows 配布用 ZIP を作成

```bash
./create_release_zip.sh
```

生成される `pawn-auto-printer.zip` を Windows に転送して使用します。

---

**更新日:** 2026年1月21日
