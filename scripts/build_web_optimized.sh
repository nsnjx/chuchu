#!/bin/bash

# Flutter Web Optimized Build Script
# This script builds Flutter web and applies optimizations:
# 1. Resource file hashing for cache busting
# 2. Main file chunking for parallel loading

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Flutter Web Optimized Build ==="
echo ""

# Step 1: Build Flutter web
echo "Step 1: Building Flutter web..."
cd "$PROJECT_DIR"
flutter build web --release

if [ $? -ne 0 ]; then
    echo "Error: Flutter build failed"
    exit 1
fi

echo ""
echo "Step 2: Applying optimizations..."
echo ""

# Step 2: Run optimization script
node "$SCRIPT_DIR/optimize_web_build.js"

if [ $? -ne 0 ]; then
    echo "Error: Optimization failed"
    exit 1
fi

echo ""
echo "=== Build Complete ==="
echo "Optimized build output: build/web"
echo ""
echo "You can now deploy the contents of build/web to your web server."

