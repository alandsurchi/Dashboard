#!/usr/bin/env bash
set -euo pipefail

echo "[vercel] Starting Flutter web build"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[vercel] Flutter not found. Installing stable channel..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get

MQTT_USERNAME_VALUE="${MQTT_USERNAME:-Flutter}"
MQTT_PASSWORD_VALUE="${MQTT_PASSWORD:-123}"

echo "[vercel] Building Flutter web output"
flutter build web --release \
  --dart-define=MQTT_USERNAME="$MQTT_USERNAME_VALUE" \
  --dart-define=MQTT_PASSWORD="$MQTT_PASSWORD_VALUE"

echo "[vercel] Build finished at build/web"