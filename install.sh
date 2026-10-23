#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================================="
echo "  📦 Building and Installing CrystalQuickLook for macOS..."
echo "=================================================================="

# 1. Build
make all

# 2. Install to ~/Applications
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/CrystalQuickLook.app"
cp -R build/CrystalQuickLook.app "$INSTALL_DIR/"

APP_PATH="$INSTALL_DIR/CrystalQuickLook.app"
APPEX_PATH="$APP_PATH/Contents/PlugIns/CrystalQuickLookPreview.appex"

echo "==> Registering QuickLook Extension..."
pluginkit -a "$APPEX_PATH" 2>/dev/null || true

echo "==> Registering with macOS LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH" 2>/dev/null || true

echo "==> Resetting QuickLook daemon..."
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

echo ""
echo "=================================================================="
echo "  ✨ CrystalQuickLook has been installed successfully! ✨"
echo "  App Location: $APP_PATH"
echo "=================================================================="
echo ""
echo "【使い方 (How to use)】:"
echo " 1. Finderで任意の .cif ファイルや POSCAR ファイルを選択します。"
echo " 2. スペースキー（Spacebar）を押すと、即座に美しい3D構造プレビューが表示されます！"
echo ""
echo "【3D操作方法】:"
echo " • マウスドラッグ: 3D視点回転"
echo " • 2本指スクロール / ピンチ: 拡大・縮小 (Zoom)"
echo " • Shift + ドラッグ: 平行移動 (Pan)"
echo " • HUDボタン: Reset, a軸視点, b軸視点, c軸視点"
echo ""
echo "【スタンドアロンアプリとしても使用可能】:"
echo " • $APP_PATH を開いて、ファイルをドラッグ＆ドロップでも確認できます。"
echo "=================================================================="
