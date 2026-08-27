#!/usr/bin/env bash
# Render static-site build for Flutter web. Root directory must be `frontend`.
set -euo pipefail

API_URL="${API_URL:-https://strollwise-api.onrender.com}"
FLUTTER_DIR="${HOME}/flutter-sdk"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "Installing Flutter SDK (stable)..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get
flutter build web --release \
  --dart-define="API_URL=${API_URL}" \
  --dart-define=ENABLE_DEMO_LOGIN=false \
  --dart-define=SENTRY_ENVIRONMENT=production
