# Pawn Auto Printer - Windows インストールガイド

## クイックスタート（推奨）

### ステップ 1: 必須ソフトウェアのインストール

以下のいずれかの方法を選択してください：

#### 方法A：自動インストール（推奨）
1. `install_all.bat` をダブルクリック
2. **管理者権限の昇格確認**が表示されたら「はい」をクリック
3. インストール完了まで待つ（5-10 分程度）

#### 方法B：手動インストール
1. **Python 3.9 以上** をインストール
   - https://www.python.org/ から最新版をダウンロード
   - インストール時に「Add Python to PATH」にチェック

2. **SumatraPDF** をインストール
   - https://www.sumatrapdfreader.org/
   - 標準インストール先にインストール（`C:\Program Files\SumatraPDF\`）

3. **Python パッケージをインストール**
   - コマンドプロンプトで以下を実行：
   ```cmd
   pip install watchdog pystray Pillow pywin32
   ```

### ステップ 2: インストール検証

1. `verify_installation.bat` を実行
2. すべての項目にチェック（✓）が表示されることを確認

### ステップ 3: 初期設定

1. `config.json` をテキストエディタで開く
2. 以下を設定：
   ```json
   {
       "watch_directory": "C:/Users/YourName/Downloads",
       "sumatra_path": "C:/Program Files/SumatraPDF/SumatraPDF.exe",
       "log_file": "printer_log.txt",
       "auto_delete": true
   }
   ```
   - `watch_directory`: 監視する フォルダ（省略時: Downloads）
   - `sumatra_path`: SumatraPDF の実行ファイルパス
   - `auto_delete`: 印刷後に元ファイルを削除するか

### ステップ 4: アプリの起動

`run_printer.bat` をダブルクリックして起動

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

### 問題 2: "Python not found" エラー
**解決方法：**
1. Python を再インストール（https://www.python.org/）
2. インストール時に「Add Python to PATH」にチェック
3. PC を再起動
4. `install_all.bat` を再実行

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

デスクトップショートカットを作成して、Windows 起動時に自動実行：

```cmd
create_desktop_shortcut.bat
```

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
