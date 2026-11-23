#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="WinBridge"
VERSION="2.5.0"
DMG_FINAL="/Users/evolv/Desktop/WinBridge.dmg"
TEMP_DMG="/tmp/pack.temp.dmg"
STAGING_DIR="/tmp/winbridge_dmg_staging"

echo "📦 Подготовка файлов для DMG..."
rm -rf "$STAGING_DIR" "$TEMP_DMG" "$DMG_FINAL"
mkdir -p "$STAGING_DIR"

# Копируем релизный бандл
if [ ! -d "/Applications/WinBridge.app" ]; then
    ./build_app.sh
fi

cp -R "/Applications/WinBridge.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Копируем иконку тома
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
fi

echo "💿 Создание образа диска DMG..."
# Создаем временный образ диска для разметки
hdiutil create -srcfolder "$STAGING_DIR" -volname "$APP_NAME" -fs HFS+ \
      -fsargs "-c c=64,a=16,e=16" -format UDRW -size 30M "$TEMP_DMG"

# Монтируем для настройки внешнего вида Finder
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 1

# Устанавливаем атрибут кастомной иконки тома
SetFile -a C "/Volumes/$APP_NAME" 2>/dev/null || true

# Настраиваем красивый вид окна в Finder через AppleScript
osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 960, 560}
        set theViewOptions to the icon view options of container window
        set icon size of theViewOptions to 110
        set arrangement of theViewOptions to not arranged
        set position of item "$APP_NAME.app" of container window to {140, 180}
        set position of item "Applications" of container window to {420, 180}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Размонтируем временный образ
hdiutil detach "$DEVICE" -force || true
sleep 1

# Конвертируем в финальный сжатый read-only DMG (UDZO)
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"

# Копируем копию в папку проекта
cp "$DMG_FINAL" "./WinBridge.dmg"

echo "✅ DMG успешно создан!"
echo "📍 Файл доступен на Рабочем столе: $DMG_FINAL"
echo "📍 И в папке проекта: $(pwd)/WinBridge.dmg"
