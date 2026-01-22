#!/bin/bash

# Web Build Verification Script
# This script verifies that the optimized build is correct

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"

echo "=== Web Build Verification ==="
echo ""

if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Error: Build directory not found: $BUILD_DIR"
    echo "Please run './scripts/build_web_optimized.sh' first."
    exit 1
fi

cd "$PROJECT_DIR"

ERRORS=0
WARNINGS=0

# Check 1: Verify all files have hash (except index.html and HTML files)
echo "1. Checking file hashing..."
UNHASHED_FILES=$(find "$BUILD_DIR" -type f \
    ! -name "index.html" \
    ! -name "*.html" \
    ! -path "*/canvaskit/*" \
    ! -name "flutter_bootstrap*.js" \
    ! -name "flutter_service_worker*.js" \
    ! -name "chunk-loader*.js" \
    ! -name "main.dart-chunk*.js" \
    ! -name "manifest*.json" \
    ! -name "version*.json" \
    ! -name "AssetManifest*.json" \
    ! -name "AssetManifest*.bin" \
    ! -name "NOTICES" \
    | grep -vE "\.(html|map)$" \
    | while read file; do
        basename=$(basename "$file")
        # Check if filename contains hash pattern (8 hex chars)
        # Hash can appear in different formats:
        # - name-hash.ext (hash after hyphen, before extension)
        # - name-hash-hash.ext (multiple hashes)
        # - name-hash (hash at the end)
        # Pattern: 8 hex chars preceded by hyphen or dot, followed by hyphen, dot, or end of string
        if ! echo "$basename" | grep -qE "[-.][a-f0-9]{8}([-.]|$)"; then
            echo "$file"
        fi
    done)

if [ -n "$UNHASHED_FILES" ]; then
    echo "   ⚠️  Warning: Found unhashed files (may be expected for some file types):"
    echo "$UNHASHED_FILES" | head -10 | sed 's/^/      /'
    if [ $(echo "$UNHASHED_FILES" | wc -l) -gt 10 ]; then
        echo "      ... and $(($(echo "$UNHASHED_FILES" | wc -l) - 10)) more"
    fi
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✅ All files are properly hashed"
fi

# Check 2: Verify index.html references
echo ""
echo "2. Checking index.html references..."
if [ -f "$BUILD_DIR/index.html" ]; then
    # Check for unhashed references (excluding bootstrap and manifest which are handled separately)
    UNHASHED_REFS=$(grep -E 'href=["'"'"']|src=["'"'"']' "$BUILD_DIR/index.html" | \
        grep -vE "(flutter_bootstrap|manifest|favicon|chuchu_ico)" | \
        grep -vE "[-.][a-f0-9]{8}([-.]|['\"])" || true)
    
    if [ -n "$UNHASHED_REFS" ]; then
        echo "   ⚠️  Warning: Found potentially unhashed references in index.html:"
        echo "$UNHASHED_REFS" | sed 's/^/      /'
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   ✅ index.html references look correct"
    fi
    
    # Check for bootstrap and manifest files
    if grep -q "flutter_bootstrap-" "$BUILD_DIR/index.html"; then
        echo "   ✅ flutter_bootstrap reference is hashed"
    else
        echo "   ❌ Error: flutter_bootstrap reference not found or not hashed"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ Error: index.html not found"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Verify no old main.dart.js exists
echo ""
echo "3. Checking for old main.dart.js..."
if find "$BUILD_DIR" -name "main.dart.js" ! -name "main.dart-*.js" 2>/dev/null | grep -q .; then
    echo "   ❌ Error: Found old main.dart.js (should be chunked)"
    find "$BUILD_DIR" -name "main.dart.js" ! -name "main.dart-*.js" | sed 's/^/      /'
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ No old main.dart.js found (correctly chunked)"
fi

# Check 4: Verify Service Worker references
echo ""
echo "4. Checking Service Worker files..."
SW_FILES=$(find "$BUILD_DIR" -name "flutter_service_worker-*.js" 2>/dev/null)
if [ -z "$SW_FILES" ]; then
    echo "   ⚠️  Warning: No Service Worker files found"
    WARNINGS=$((WARNINGS + 1))
else
    SW_COUNT=0
    for sw_file in $SW_FILES; do
        SW_COUNT=$((SW_COUNT + 1))
        # Check for old main.dart.js references
        if grep -q "main\.dart\.js" "$sw_file" 2>/dev/null && ! grep -q "main\.dart-chunk\|chunk-loader" "$sw_file" 2>/dev/null; then
            echo "   ❌ Error: Service Worker contains old main.dart.js reference: $(basename $sw_file)"
            ERRORS=$((ERRORS + 1))
        fi
        # Check for unhashed icon references
        if grep -q "chuchu_ico\.ico" "$sw_file" 2>/dev/null && ! grep -q "chuchu_ico-[a-f0-9]" "$sw_file" 2>/dev/null; then
            echo "   ⚠️  Warning: Service Worker may contain unhashed icon reference: $(basename $sw_file)"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
    if [ $SW_COUNT -gt 0 ] && [ $ERRORS -eq 0 ]; then
        echo "   ✅ Service Worker files look correct ($SW_COUNT files)"
    fi
fi

# Check 5: Verify chunk files exist
echo ""
echo "5. Checking chunk files..."
CHUNK_FILES=$(find "$BUILD_DIR" -name "main.dart-chunk*.js" 2>/dev/null | wc -l)
LOADER_FILES=$(find "$BUILD_DIR" -name "chunk-loader-main.dart*.js" 2>/dev/null | wc -l)

if [ $CHUNK_FILES -gt 0 ]; then
    echo "   ✅ Found $CHUNK_FILES chunk files"
    if [ $LOADER_FILES -gt 0 ]; then
        echo "   ✅ Found $LOADER_FILES chunk loader file(s)"
    else
        echo "   ❌ Error: No chunk loader file found"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ⚠️  Warning: No chunk files found (main.dart.js may not have been chunked)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 6: Verify icon files
echo ""
echo "6. Checking icon files..."
ICON_FILES=$(find "$BUILD_DIR" -name "*chuchu_ico*.ico" 2>/dev/null)
if [ -z "$ICON_FILES" ]; then
    echo "   ⚠️  Warning: No chuchu_ico files found"
    WARNINGS=$((WARNINGS + 1))
else
    ICON_COUNT=$(echo "$ICON_FILES" | wc -l)
    HASHED_ICONS=$(echo "$ICON_FILES" | grep -E "chuchu_ico-[a-f0-9]{8}\.ico" | wc -l)
    if [ $HASHED_ICONS -gt 0 ]; then
        echo "   ✅ Found $HASHED_ICONS hashed icon file(s)"
    else
        echo "   ⚠️  Warning: Icon files found but may not be hashed"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Summary
echo ""
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed!"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) found, but no errors"
    exit 0
else
    echo "❌ $ERRORS error(s) and $WARNINGS warning(s) found"
    echo ""
    echo "Please review the errors above and fix them before deploying."
    exit 1
fi
