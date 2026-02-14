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

# Build for web
echo "Building for web..."
flutter build web --release

echo "Build complete!"
