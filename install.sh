#!/bin/bash
# Install TagClip to /Applications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$SCRIPT_DIR/dist/TagClip.app"
APP_DST="/Applications/TagClip.app"

if [ ! -d "$APP_SRC" ]; then
    echo "错误：找不到 $APP_SRC，请先运行 ./build.sh" >&2
    exit 1
fi

if [ -d "$APP_DST" ]; then
    echo "检测到已安装的旧版本，正在移除..."
    rm -rf "$APP_DST"
fi

cp -R "$APP_SRC" "$APP_DST"
echo "已安装到 $APP_DST"

xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
echo "已清除隔离属性（如果存在）"

echo ""
echo "完成！运行方式："
echo "  open /Applications/TagClip.app"
