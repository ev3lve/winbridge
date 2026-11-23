#!/bin/bash
set -e

# Переход в директорию проекта
cd "$(dirname "$0")"

# Остановка старой версии если работает
killall WinBridge 2>/dev/null || true
killall WinToMac 2>/dev/null || true

echo "📦 Сборка релизной версии WinBridge..."
swift build -c release

APP_NAME="WinBridge"
BUNDLE_ID="com.evolv.winbridge"
BUILD_DIR=".build/release"
APP_DIR="/Applications/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📂 Подготовка бандла $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Копируем бинарник
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Копируем фирменную Retina иконку
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Создаем Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.5.0</string>
    <key>CFBundleVersion</key>
    <string>2.5.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Подписываем ad-hoc для стабильной работы Accessibility
codesign --force --deep --sign - "$APP_DIR"

# Удаляем WinToMac.app из папки проекта если остался
rm -rf "WinToMac.app"
# Создаем символическую ссылку или копию в проекте
cp -R "$APP_DIR" "$APP_NAME.app"

echo "🚀 Запуск $APP_NAME..."
open "$APP_DIR"

echo "✅ $APP_NAME готов и запущен!"
