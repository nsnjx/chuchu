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

# Step 0: Clean old build directory
echo "Step 0: Cleaning old build directory..."
cd "$PROJECT_DIR"
if [ -d "build/web" ]; then
    rm -rf build/web
    echo "✅ Removed old build/web directory"
else
    echo "ℹ️  No existing build/web directory to clean"
fi
echo ""

# Step 1: Build Flutter web
echo "Step 1: Building Flutter web..."
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
echo "Step 3: Verifying build..."
echo ""

# Step 3: Run verification script
if [ -f "$SCRIPT_DIR/verify_build.sh" ]; then
    "$SCRIPT_DIR/verify_build.sh"
    VERIFY_EXIT_CODE=$?
    if [ $VERIFY_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "⚠️  Warning: Build verification found issues"
        echo "You can still deploy, but please review the warnings above."
    fi
else
    echo "⚠️  Warning: Verification script not found, skipping verification"
fi

echo ""
echo "=== Build Complete ==="
echo "Optimized build output: build/web"
echo ""
echo "You can now deploy the contents of build/web to your web server."

