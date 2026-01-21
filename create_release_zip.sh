#!/bin/bash
# Mac用 - Windows配布用zipファイル作成スクリプト

cd "$(dirname "$0")"

ZIP_NAME="pawn-auto-printer.zip"
TEMP_DIR="pawn-auto-printer"

echo "================================================"
echo "  Windows配布用 ZIP 作成"
echo "================================================"
echo ""

# 既存のzipを削除
if [ -f "$ZIP_NAME" ]; then
    echo "既存の $ZIP_NAME を削除..."
    rm "$ZIP_NAME"
fi

# 一時ディレクトリを削除
if [ -d "$TEMP_DIR" ]; then
    echo "既存の一時ディレクトリを削除..."
    rm -rf "$TEMP_DIR"
fi

echo "ファイルをコピー中..."
mkdir -p "$TEMP_DIR"

# 必要なファイルをコピー
cp -r \
    auto_printer.py \
    config.json \
    *.bat \
    *.vbs \
    *.ps1 \
    *.md \
    *.html \
    *.png \
    *.ico \
    .github \
    "$TEMP_DIR/" 2>/dev/null

echo "Mac固有ファイルを除外..."
# Mac固有ファイルを削除
find "$TEMP_DIR" -name ".DS_Store" -delete
find "$TEMP_DIR" -name ".__*" -delete

echo "ZIP作成中..."
# Windows互換のzipを作成（Mac固有の属性を除外）
zip -r -X "$ZIP_NAME" "$TEMP_DIR"

# 一時ディレクトリを削除
rm -rf "$TEMP_DIR"

if [ -f "$ZIP_NAME" ]; then
    SIZE=$(du -h "$ZIP_NAME" | cut -f1)
    echo ""
    echo "================================================"
    echo "✅ 作成完了: $ZIP_NAME ($SIZE)"
    echo "================================================"
    echo ""
    echo "次の手順:"
    echo "  1. このzipファイルをWindowsに転送"
    echo "  2. Windows上で右クリック →「すべて展開」"
    echo "  3. install_all.bat を右クリック →「管理者として実行」"
    echo ""
else
    echo ""
    echo "❌ エラー: ZIP作成に失敗しました"
    exit 1
fi
