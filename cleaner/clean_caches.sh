#!/bin/bash

OS="$(uname)"

if [[ "$OS" == *"MINGW"* ]] || [[ "$OS" == *"CYGWIN"* ]] || [[ "$OS" == *"MSYS"* ]]; then
  echo "❌ Error: This script is not compatible with Windows (Git Bash/Cygwin/MSYS)."
  echo "Please use a PowerShell script for Windows environments."
  exit 1
fi

echo "🧹 Starting system cache cleanup..."

echo "📦 1. Cleaning Dotnet..."
dotnet workload clean --all
dotnet nuget locals all --clear

echo "📦 2. Cleaning NPM..."
npm cache clean --force

echo "📦 3. Cleaning Bun..."
rm -rf ~/.bun/install/cache

echo "🦕 4. Cleaning Deno..."
if [ "$OS" = "Darwin" ]; then
  rm -rf ~/Library/Caches/deno
else
  rm -rf ~/.cache/deno
fi

echo "📱 5. Cleaning Flutter/Dart..."
flutter pub cache clean -f
rm -rf ~/.pub-cache/hosted/

echo "🤖 6. Cleaning Android (Gradle)..."
rm -rf ~/.gradle/caches/

echo "🦀 7. Cleaning Rust (Cargo)..."
rm -rf ~/.cargo/registry/cache
rm -rf ~/.cargo/registry/src

echo "🐍 8. Cleaning Python (pip & uv)..."
pip cache purge 2>/dev/null
uv cache clean 2>/dev/null
if [ "$OS" = "Darwin" ]; then
  rm -rf ~/Library/Caches/pip
  rm -rf ~/Library/Caches/uv
else
  rm -rf ~/.cache/pip
  rm -rf ~/.cache/uv
fi

echo "✨ Cleanup completed successfully!"
