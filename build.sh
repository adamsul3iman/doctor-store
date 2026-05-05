#!/bin/bash

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation
flutter doctor

# Enable web support
flutter config --enable-web

# Generate assets/env.txt from environment variables (for Vercel deployment)
echo "Setting up environment variables..."
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
    echo "SUPABASE_URL=$SUPABASE_URL" > assets/env.txt
    echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> assets/env.txt
    echo "✅ Generated assets/env.txt from environment variables"
else
    echo "⚠️ Warning: SUPABASE_URL or SUPABASE_ANON_KEY not set. Using existing env.txt if available."
fi

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build for web with HTML renderer (smaller bundle, faster loading)
echo "Building for web with HTML renderer..."
flutter build web --release

# Ensure PWA/static files are present in the build output (Vercel serves build/web)
cp -f web/manifest.json build/web/manifest.json
cp -f web/favicon.png build/web/favicon.png
cp -f web/service-worker.js build/web/service-worker.js
mkdir -p build/web/icons
cp -f web/icons/* build/web/icons/ 2>/dev/null || true

echo "Build complete!"
