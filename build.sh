#!/bin/bash
# Build TagClip.app (release)
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building (release)..."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if [ -n "${DEVELOPER_DIR:-}" ]; then
  xcrun swift build -c release
else
  swift build -c release
fi

echo "==> Assembling .app..."
rm -rf dist/TagClip.app
mkdir -p dist/TagClip.app/Contents/MacOS dist/TagClip.app/Contents/Resources
cp .build/release/TagClip dist/TagClip.app/Contents/MacOS/TagClip
cp Resources/Info.plist dist/TagClip.app/Contents/Info.plist
cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns \
   dist/TagClip.app/Contents/Resources/AppIcon.icns

echo "==> Signing (ad-hoc)..."
codesign --force --sign - dist/TagClip.app
codesign --verify --verbose=2 dist/TagClip.app

echo "==> Packaging .dmg..."
rm -rf .dmg-staging dist/TagClip.dmg
mkdir -p .dmg-staging
cp -R dist/TagClip.app .dmg-staging/
ln -s /Applications .dmg-staging/Applications
hdiutil create -volname "TagClip" -srcfolder .dmg-staging \
  -ov -format UDZO dist/TagClip.dmg >/dev/null
rm -rf .dmg-staging

echo "==> Packaging macOS zip..."
rm -f dist/TagClip-macOS.zip
(cd dist && zip -qry -X TagClip-macOS.zip TagClip.app)

echo "==> Done: dist/TagClip.app + dist/TagClip.dmg + dist/TagClip-macOS.zip"
echo "    本机安装: ./install.sh"
echo "    分发: 把 dist/TagClip.dmg 发给别人，拖进「应用程序」即可"
