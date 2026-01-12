# Flutter Web Build Optimization Documentation

## Overview

This optimization script solves the issue of Flutter Web resources not updating after deployment and improves loading performance. It implements the following two main features:

1. **Resource File Hashing**: Adds Hash values to all resource files to solve browser cache update issues
2. **Large File Chunking**: Splits `main.dart.js` into multiple files for parallel loading, improving first-screen rendering performance

## Usage

### Method 1: Using the Convenience Script (Recommended)

```bash
./scripts/build_web_optimized.sh
```

This script automatically executes:
1. `flutter build web --release`
2. Runs the optimization script

### Method 2: Manual Execution

```bash
# 1. Build Flutter Web first
flutter build web --release

# 2. Run the optimization script
node scripts/optimize_web_build.js
```

## Optimization Details

### 1. Resource File Hashing

- **Purpose**: Solves the issue of features not updating in time due to browser caching
- **Implementation**:
  - Traverse all files in the `build/web` directory (except `index.html`)
  - Calculate MD5 Hash value for each file (first 8 characters)
  - Rename files to `filename-[hash].ext` format
  - Update all file references (HTML, JS, JSON, CSS, etc.)

**Example**:
```
main.dart.js → main.dart-a1b2c3d4.js
assets/image.png → assets/image-e5f6g7h8.png
```

### 2. Large File Chunking

- **Purpose**: Improves first-screen rendering performance by utilizing browser parallel loading capabilities
- **Implementation**:
  - Split `main.dart.js` into multiple files of 500KB each
  - Create a chunk loader that loads all chunks in parallel via XHR
  - Concatenate and execute in order after loading completes
  - Update references in `flutter_bootstrap.js`

**Chunk File Naming**:
```
main.dart-chunk0.js
main.dart-chunk1.js
main.dart-chunk2.js
...
```

**Loader**:
- Creates `chunk-loader-main.dart.js` file
- Uses Promise.all to load all chunks in parallel
- Displays loading progress
- Supports error handling

## Configuration

You can modify the following configuration in `scripts/optimize_web_build.js`:

```javascript
const CHUNK_SIZE = 500 * 1024; // Size of each chunk (default 500KB)
```

## Output

The optimized files are located in the `build/web` directory and can be deployed directly to a web server.

## Notes

1. **Must use Release mode**: `flutter build web --release`
2. **Node.js requirement**: Node.js environment is required to run the optimization script
3. **Deployment**: Optimized files can be deployed directly without additional configuration
4. **CDN support**: Hashed file names allow safe use of CDN, file name changes automatically trigger cache updates

## How It Works

### Optimization Process

```
1. Split main.dart.js (if exists)
   ↓
2. Hash all resource files
   ↓
3. Update references in chunk loader
   ↓
4. Update resource references in all files
```

### Reference Update Strategy

The script updates the following types of references:
- HTML tag attributes: `src`, `href`, `data-src`, etc.
- JavaScript strings: File paths within quotes
- CSS URLs: `url('path/to/file')`
- JSON properties: `{"src": "file.js"}`, etc.

## Troubleshooting

### Issue: Page cannot load after optimization

1. Check browser console error messages
2. Verify all chunk files have been generated correctly
3. Check if `mainJsPath` in `flutter_bootstrap.js` is updated correctly

### Issue: Resource file 404

1. Check if file references are updated correctly
2. Verify if hashed file names are correct
3. Check server configuration to ensure support for hashed file names

## Technical Details

- **Hash algorithm**: MD5 (first 8 characters)
- **Chunk size**: 500KB (configurable)
- **Loading method**: XMLHttpRequest parallel loading
- **Execution order**: Chunks are concatenated in order and executed together
