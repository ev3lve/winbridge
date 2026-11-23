#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "🔨 Сборка и запуск WinBridge..."
swift run WinBridge
