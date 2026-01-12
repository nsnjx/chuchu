# Flutter Web Optimization Quick Start

## One-Click Build and Optimization

```bash
./scripts/build_web_optimized.sh
```

## Manual Steps

```bash
# 1. Build
flutter build web --release

# 2. Optimize
node scripts/optimize_web_build.js
```

## Optimization Benefits

✅ **Resource File Hashing** - Solves cache update issues
- All files (except index.html) will have Hash suffixes added
- File name changes automatically trigger browser cache updates

✅ **Large File Chunking** - Improves loading performance  
- main.dart.js is split into multiple 500KB chunks
- Parallel loading improves first-screen rendering speed

## Deployment

The optimized files are in the `build/web` directory and can be deployed directly.

## More Information

For detailed documentation, see [README_WEB_OPTIMIZATION.md](./README_WEB_OPTIMIZATION.md)
