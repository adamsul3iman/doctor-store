#!/bin/bash

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation
flutter doctor

# Enable web support
flutter config --enable-web

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build for web with HTML renderer (smaller bundle, faster loading)
echo "Building for web with HTML renderer..."
flutter build web --release --web-renderer html

# Ensure PWA/static files are present in the build output (Vercel serves build/web)
cp -f web/manifest.json build/web/manifest.json
cp -f web/favicon.png build/web/favicon.png
cp -f web/service-worker.js build/web/service-worker.js
mkdir -p build/web/icons
cp -f web/icons/* build/web/icons/ 2>/dev/null || true

echo "Build complete!"
