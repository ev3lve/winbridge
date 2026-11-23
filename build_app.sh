#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🛑 Завершение старых процессов..."
killall WinToMac 2>/dev/null || true

echo "📦 Сборка релизной версии WinToMac..."
swift build -c release

APP_NAME="WinToMac"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

cat << 'PLIST' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WinToMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.evolv.wintomac</string>
    <key>CFBundleName</key>
    <string>WinToMac</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

chmod +x "$MACOS/$APP_NAME"

echo "🔏 Подпись приложения (ad-hoc codesign для TCC / Accessibility)..."
codesign -s - --force --deep --identifier "com.evolv.wintomac" "$APP_DIR"

echo "📂 Копирование в /Applications/..."
rm -rf "/Applications/$APP_DIR"
cp -R "$APP_DIR" /Applications/

echo "🚀 Запуск приложения из /Applications/..."
open "/Applications/$APP_DIR"

echo "✅ WinToMac готов и запущен!"
