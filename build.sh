#!/bin/bash
set -e

echo "===> Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
export PATH="$PATH:$(pwd)/flutter/bin"

echo "===> Verifying Flutter install..."
flutter --version
flutter config --no-analytics
flutter doctor -v || true

echo "===> Getting dependencies..."
flutter pub get

echo "===> Building Flutter Web (release)..."
flutter build web --release --dart-define=API_BASE_URL=https://paddleq-api-vince-grbqc7e9fjfra4g5.southeastasia-01.azurewebsites.net

echo "===> Build complete. Output in build/web"