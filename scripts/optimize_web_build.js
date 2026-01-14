#!/usr/bin/env node

/**
 * Flutter Web Build Optimizer
 * 
 * This script optimizes Flutter web builds by:
 * 1. Adding hash to all resource files (except index.html) for cache busting
 * 2. Splitting main.dart.js into multiple chunks for parallel loading
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Configuration
const BUILD_DIR = path.join(__dirname, '..', 'build', 'web');
const CHUNK_SIZE = 500 * 1024; // 500KB per chunk
const INDEX_HTML = 'index.html';

// Resource map: original path -> hashed path
const resourceMap = new Map();

/**
 * Calculate MD5 hash of a file
 */
function calculateHash(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash('md5').update(content).digest('hex').substring(0, 8);
}

/**
 * Get file extension
 */
function getExtension(filePath) {
  return path.extname(filePath);
}

/**
 * Get file name without extension
 */
function getBaseName(filePath) {
  const ext = getExtension(filePath);
  return path.basename(filePath, ext);
}

/**
 * Generate hashed filename
 */
function generateHashedName(filePath) {
  const hash = calculateHash(filePath);
  const ext = getExtension(filePath);
  const baseName = getBaseName(filePath);
  const dir = path.dirname(filePath);
  const newName = `${baseName}-${hash}${ext}`;
  return path.join(dir, newName);
}

/**
 * Recursively find all files in directory
 */
function findAllFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      findAllFiles(filePath, fileList);
    } else {
      // Skip index.html
      if (path.basename(filePath) !== INDEX_HTML) {
        fileList.push(filePath);
      }
    }
  });
  
  return fileList;
}

/**
 * Get relative path from build directory
 */
function getRelativePath(filePath) {
  return path.relative(BUILD_DIR, filePath).replace(/\\/g, '/');
}

/**
 * Rename file with hash
 */
function hashFile(filePath) {
  const hashedPath = generateHashedName(filePath);
  const relativePath = getRelativePath(filePath);
  const relativeHashedPath = getRelativePath(hashedPath);
  
  // Only rename if different
  if (filePath !== hashedPath) {
    fs.renameSync(filePath, hashedPath);
    resourceMap.set(relativePath, relativeHashedPath);
    console.log(`Hashed: ${relativePath} -> ${relativeHashedPath}`);
  }
  
  return hashedPath;
}

/**
 * Update references in text content
 */
function updateReferences(content, filePath) {
  let updated = content;
  
  // Update all resource references
  // Sort by path length (longest first) to handle nested paths correctly
  const sortedEntries = Array.from(resourceMap.entries()).sort((a, b) => b[0].length - a[0].length);
  
  sortedEntries.forEach(([originalPath, hashedPath]) => {
    const originalBase = path.basename(originalPath);
    const hashedBase = path.basename(hashedPath);
    const originalDir = path.dirname(originalPath);
    const hashedDir = path.dirname(hashedPath);
    
    // 1. Exact path matches (with quotes)
    updated = updated.replace(new RegExp(`"${escapeRegex(originalPath)}"`, 'g'), `"${hashedPath}"`);
    updated = updated.replace(new RegExp(`'${escapeRegex(originalPath)}'`, 'g'), `'${hashedPath}'`);
    updated = updated.replace(new RegExp(`\`${escapeRegex(originalPath)}\``, 'g'), `\`${hashedPath}\``);
    
    // 2. Filename matches in paths
    // Match: "path/to/filename.ext" or 'path/to/filename.ext'
    const filenamePattern = escapeRegex(originalBase);
    // Use string concatenation to avoid template literal issues with backticks
    const quotePattern = '(["\'`])';
    const pathPattern = '([^"\'`]*?)';
    updated = updated.replace(
      new RegExp(quotePattern + pathPattern + filenamePattern + quotePattern, 'g'),
      (match, quote1, prefix, quote2) => {
        // Preserve the directory structure if it matches
        if (prefix.endsWith(originalDir)) {
          return quote1 + prefix.replace(originalDir, hashedDir) + hashedBase + quote2;
        }
        return quote1 + prefix + hashedBase + quote2;
      }
    );
    
    // 3. URL references: url('path/to/file.ext')
    updated = updated.replace(
      new RegExp(`url\\(['"]?([^'"]*?)${filenamePattern}['"]?\\)`, 'gi'),
      (match, prefix) => {
        if (prefix.endsWith(originalDir)) {
          return `url('${prefix.replace(originalDir, hashedDir)}${hashedBase}')`;
        }
        return `url('${prefix}${hashedBase}')`;
      }
    );
    
    // 4. HTML attributes: src="file.ext", href="file.ext"
    updated = updated.replace(
      new RegExp(`(src|href|data-src|data-href)=["']([^"']*?)${filenamePattern}["']`, 'gi'),
      (match, attr, prefix) => {
        if (prefix.endsWith(originalDir)) {
          return `${attr}="${prefix.replace(originalDir, hashedDir)}${hashedBase}"`;
        }
        return `${attr}="${prefix}${hashedBase}"`;
      }
    );
    
    // 5. JSON property values: {"src": "file.ext"}
    updated = updated.replace(
      new RegExp(`(["'](?:src|href|url|path|file|mainJsPath)["']\\s*:\\s*["'])([^"']*?)${filenamePattern}(["'])`, 'gi'),
      (match, prefix, pathPrefix, suffix) => {
        if (pathPrefix.endsWith(originalDir)) {
          return prefix + pathPrefix.replace(originalDir, hashedDir) + hashedBase + suffix;
        }
        return prefix + pathPrefix + hashedBase + suffix;
      }
    );
    
    // 6. Dynamic import() statements: import('path/to/file.js')
    updated = updated.replace(
      new RegExp(`import\\(['"]?([^'"]*?)${filenamePattern}['"]?\\)`, 'gi'),
      (match, prefix) => {
        if (prefix.endsWith(originalDir)) {
          return `import('${prefix.replace(originalDir, hashedDir)}${hashedBase}')`;
        }
        return `import('${prefix}${hashedBase}')`;
      }
    );
    
    // 7. Service Worker file references (in JSON format)
    // Pattern: "canvaskit/chromium/canvaskit-86e461cf.js": "hash"
    // Match both with and without quotes around the path
    // Note: Service Worker uses MD5 hash of file content (32 chars)
    try {
      const hashedFilePath = path.join(BUILD_DIR, hashedPath);
      let fileHash = '';
      if (fs.existsSync(hashedFilePath)) {
        const content = fs.readFileSync(hashedFilePath);
        fileHash = crypto.createHash('md5').update(content).digest('hex');
      } else {
        // Fallback: use hash from filename if file doesn't exist
        const hashMatch = hashedBase.match(/-([a-f0-9]{8})/i);
        fileHash = hashMatch ? hashMatch[1].repeat(4) : '00000000000000000000000000000000';
      }
      
      updated = updated.replace(
        new RegExp(`(["'])([^"']*?)${escapeRegex(originalBase)}\\1\\s*:\\s*["'][^"']*["']`, 'g'),
        (match, quote, prefix) => {
          if (prefix.endsWith(originalDir) || prefix === originalDir) {
            const newPrefix = prefix.endsWith(originalDir) 
              ? prefix.replace(originalDir, hashedDir)
              : hashedDir;
            return `${quote}${newPrefix}${hashedBase}${quote}: "${fileHash}"`;
          }
          return `${quote}${prefix}${hashedBase}${quote}: "${fileHash}"`;
        }
      );
      
      // 7b. Service Worker file references without quotes around path
      // Pattern: canvaskit/chromium/canvaskit-86e461cf.js: "hash"
      updated = updated.replace(
        new RegExp(`([^"']*?)${escapeRegex(originalBase)}\\s*:\\s*["'][^"']*["']`, 'g'),
        (match, prefix) => {
          if (prefix.endsWith(originalDir) || prefix === originalDir) {
            const newPrefix = prefix.endsWith(originalDir) 
              ? prefix.replace(originalDir, hashedDir)
              : hashedDir;
            return `${newPrefix}${hashedBase}: "${fileHash}"`;
          }
          return `${prefix}${hashedBase}: "${fileHash}"`;
        }
      );
    } catch (e) {
      // If hash calculation fails, skip this update
      console.warn(`Warning: Failed to calculate hash for ${hashedPath}: ${e.message}`);
    }
    
    // 8. Simple string replacement for exact matches (fallback)
    updated = updated.replace(new RegExp(escapeRegex(originalPath), 'g'), hashedPath);
  });
  
  return updated;
}

/**
 * Escape special regex characters
 */
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Update file references
 */
function updateFileReferences(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const updated = updateReferences(content, filePath);
  
  if (content !== updated) {
    fs.writeFileSync(filePath, updated, 'utf8');
    console.log(`Updated references in: ${getRelativePath(filePath)}`);
  }
}

/**
 * Split main.dart.js into chunks
 */
function splitMainDartJs(mainDartJsPath) {
  console.log('\n=== Splitting main.dart.js ===');
  
  const content = fs.readFileSync(mainDartJsPath, 'utf8');
  const fileSize = content.length;
  const chunks = [];
  const chunkCount = Math.ceil(fileSize / CHUNK_SIZE);
  
  console.log(`File size: ${(fileSize / 1024 / 1024).toFixed(2)}MB`);
  console.log(`Splitting into ${chunkCount} chunks (${(CHUNK_SIZE / 1024).toFixed(0)}KB per chunk)`);
  
  // Split into chunks
  for (let i = 0; i < chunkCount; i++) {
    const start = i * CHUNK_SIZE;
    const end = Math.min(start + CHUNK_SIZE, fileSize);
    const chunk = content.substring(start, end);
    chunks.push(chunk);
  }
  
  // Get original file info
  const hash = calculateHash(mainDartJsPath);
  const baseName = getBaseName(mainDartJsPath);
  const ext = getExtension(mainDartJsPath);
  const dir = path.dirname(mainDartJsPath);
  
  // Write chunk files
  const chunkFiles = [];
  chunks.forEach((chunk, index) => {
    const chunkFileName = `${baseName}-chunk${index}${ext}`;
    const chunkPath = path.join(dir, chunkFileName);
    fs.writeFileSync(chunkPath, chunk, 'utf8');
    chunkFiles.push(chunkFileName);
    console.log(`Created chunk ${index + 1}/${chunkCount}: ${chunkFileName} (${(chunk.length / 1024).toFixed(2)}KB)`);
  });
  
  // Delete original file
  fs.unlinkSync(mainDartJsPath);
  console.log(`Deleted original: ${path.basename(mainDartJsPath)}`);
  
  return {
    chunkFiles,
    chunkCount,
    hash,
    baseName
  };
}

/**
 * Create chunk loader script
 */
function createChunkLoader(chunkInfo) {
  const baseName = chunkInfo.baseName;
  const loaderScript = `
// Chunk loader for ${baseName}.js
// Loads chunks in parallel and concatenates them before execution
(function() {
  'use strict';
  
  const chunks = ${JSON.stringify(chunkInfo.chunkFiles)};
  const basePath = document.baseURI || '';
  let loadedChunks = 0;
  const totalChunks = chunks.length;
  
  console.log(\`Loading \${totalChunks} chunks for ${baseName}.js...\`);
  
  // Load all chunks in parallel using XHR
  const loadPromises = chunks.map((chunk, index) => {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', basePath + chunk, true);
      xhr.onload = function() {
        if (xhr.status === 200 || xhr.status === 0) {
          loadedChunks++;
          console.log(\`Loaded chunk \${index + 1}/\${totalChunks} (\${((loadedChunks / totalChunks) * 100).toFixed(1)}%)\`);
          resolve(xhr.responseText);
        } else {
          reject(new Error(\`Failed to load chunk \${index + 1}: HTTP \${xhr.status}\`));
        }
      };
      xhr.onerror = function() {
        reject(new Error(\`Network error loading chunk \${index + 1}\`));
      };
      xhr.send();
    });
  });
  
  // Wait for all chunks to load, then concatenate and execute
  Promise.all(loadPromises)
    .then(chunkContents => {
      console.log('All chunks loaded, concatenating...');
      const fullCode = chunkContents.join('');
      
      // Create and execute script
      const script = document.createElement('script');
      script.type = 'application/javascript';
      script.textContent = fullCode;
      
      // Insert before other scripts to maintain execution order
      const firstScript = document.getElementsByTagName('script')[0];
      if (firstScript && firstScript.parentNode) {
        firstScript.parentNode.insertBefore(script, firstScript);
      } else {
        document.head.appendChild(script);
      }
      
      console.log('${baseName}.js chunks loaded and executed successfully');
    })
    .catch(error => {
      console.error('Error loading ${baseName}.js chunks:', error);
      // Try to show user-friendly error
      if (document.body) {
        document.body.innerHTML = '<div style="padding: 20px; text-align: center; font-family: sans-serif;"><h2>Loading Error</h2><p>Failed to load application resources. Please refresh the page and try again.</p></div>';
      }
      throw error;
    });
})();
`;
  
  const loaderPath = path.join(BUILD_DIR, `chunk-loader-${baseName}.js`);
  fs.writeFileSync(loaderPath, loaderScript.trim(), 'utf8');
  console.log(`Created chunk loader: chunk-loader-${baseName}.js`);
  
  return `chunk-loader-${baseName}.js`;
}

/**
 * Update index.html to use chunk loader
 */
function updateIndexHtml(chunkLoaderPath) {
  const indexPath = path.join(BUILD_DIR, INDEX_HTML);
  let content = fs.readFileSync(indexPath, 'utf8');
  
  // Replace flutter_bootstrap.js with chunk loader
  content = content.replace(
    /<script[^>]*src=["']flutter_bootstrap\.js["'][^>]*><\/script>/i,
    `<script src="${chunkLoaderPath}" async></script>`
  );
  
  fs.writeFileSync(indexPath, content, 'utf8');
  console.log(`Updated ${INDEX_HTML} to use chunk loader`);
}

/**
 * Create copies of canvaskit files with original filenames (without hash)
 * This ensures Flutter can find canvaskit files by their original names
 */
function createCanvaskitOriginals() {
  const canvaskitDir = path.join(BUILD_DIR, 'canvaskit');
  if (!fs.existsSync(canvaskitDir)) {
    return;
  }
  
  console.log('Creating canvaskit file copies for original filenames...');
  
  // Process both root canvaskit directory and chromium subdirectory
  const canvaskitDirs = [
    canvaskitDir,
    path.join(canvaskitDir, 'chromium')
  ];
  
  canvaskitDirs.forEach(canvaskitSubDir => {
    if (!fs.existsSync(canvaskitSubDir)) {
      return;
    }
    
    // Find all canvaskit files
    const canvaskitFiles = fs.readdirSync(canvaskitSubDir)
      .filter(f => {
        const fullPath = path.join(canvaskitSubDir, f);
        try {
          const stat = fs.statSync(fullPath);
          return stat.isFile() && /\.(js|wasm|symbols)$/i.test(f);
        } catch (e) {
          return false;
        }
      })
      .map(f => path.join(canvaskitSubDir, f));
    
    if (canvaskitFiles.length === 0) {
      return;
    }
    
    // Group files by base name (without hash)
    const filesByBaseName = new Map();
    
    canvaskitFiles.forEach(filePath => {
      const fileName = path.basename(filePath);
      const extMatch = fileName.match(/\.([^.]+)$/);
      if (!extMatch) {
        return;
      }
      const extension = extMatch[0];
      const nameWithoutExt = fileName.substring(0, fileName.length - extension.length);
      const nameWithoutHash = nameWithoutExt.replace(/(-[a-f0-9]{8})+$/i, '');
      const baseName = nameWithoutHash + extension;
      
      if (!filesByBaseName.has(baseName)) {
        filesByBaseName.set(baseName, []);
      }
      filesByBaseName.get(baseName).push({ path: filePath, fileName });
    });
    
    // Create original filename copies
    filesByBaseName.forEach((files, baseName) => {
      // Find the file with the most hashes (likely the most recent/complete one)
      const sortedFiles = files.sort((a, b) => {
        const aHashCount = (a.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        const bHashCount = (b.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        return bHashCount - aHashCount;
      });
      const sourceFile = sortedFiles[0];
      
      // Create original filename copy (no hash)
      if (baseName !== sourceFile.fileName) {
        const originalPath = path.join(canvaskitSubDir, baseName);
        if (fs.existsSync(originalPath)) {
          try {
            const stat = fs.statSync(originalPath);
            if (!stat.isFile() || stat.isSymbolicLink()) {
              fs.unlinkSync(originalPath);
            } else {
              return; // Already exists
            }
          } catch (e) {
            // Ignore errors
          }
        }
        
        try {
          fs.copyFileSync(sourceFile.path, originalPath);
          const relativePath = getRelativePath(originalPath);
          console.log(`Copied canvaskit file: ${relativePath} <- ${path.basename(sourceFile.path)}`);
        } catch (copyError) {
          console.warn(`Failed to copy canvaskit file ${baseName}: ${copyError.message}`);
        }
      }
    });
  });
}

/**
 * Create copies of asset files (fonts, images, etc.) with original filenames (without hash)
 * This ensures Flutter can find assets by their original names
 * We use file copies instead of symlinks because http-server may not support symlinks
 */
function createFontSymlinks() {
  const doubleAssetsDir = path.join(BUILD_DIR, 'assets', 'assets');
  if (!fs.existsSync(doubleAssetsDir)) {
    return;
  }
  
  console.log('Creating asset file copies for original filenames...');
  
  // Process multiple asset directories
  const assetDirs = ['fonts', 'images', 'icons', 'audio', 'video'];
  
  assetDirs.forEach(dirName => {
    const assetDir = path.join(doubleAssetsDir, dirName);
    if (!fs.existsSync(assetDir)) {
      return;
    }
    
    // Find all asset files in the directory (only real files with extensions, not symlinks)
    const assetFiles = fs.readdirSync(assetDir)
      .filter(f => {
        const fullPath = path.join(assetDir, f);
        try {
          const stat = fs.statSync(fullPath);
          // Only process regular files (not symlinks) with common asset extensions
          return stat.isFile() && /\.(ttf|otf|woff|woff2|png|jpg|jpeg|gif|svg|webp|ico|mp3|wav|ogg|mp4|webm)$/i.test(f);
        } catch (e) {
          return false;
        }
      })
      .map(f => path.join(assetDir, f));
    
    if (assetFiles.length === 0) {
      return;
    }
    
    // Track which original filenames we've already created
    const createdOriginals = new Set();
    
    // Group files by base name (without hash)
    const filesByBaseName = new Map();
    
    assetFiles.forEach(assetPath => {
      const fileName = path.basename(assetPath);
      const extMatch = fileName.match(/\.([^.]+)$/);
      if (!extMatch) {
        return;
      }
      const extension = extMatch[0];
      const nameWithoutExt = fileName.substring(0, fileName.length - extension.length);
      const nameWithoutHash = nameWithoutExt.replace(/(-[a-f0-9]{8})+$/i, '');
      const baseName = nameWithoutHash + extension;
      
      if (!filesByBaseName.has(baseName)) {
        filesByBaseName.set(baseName, []);
      }
      filesByBaseName.get(baseName).push({ path: assetPath, fileName });
    });
    
    // For each base name, create copies for all hash variations
    filesByBaseName.forEach((files, baseName) => {
      // Find the file with the most hashes (likely the most recent/complete one)
      const sortedFiles = files.sort((a, b) => {
        const aHashCount = (a.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        const bHashCount = (b.fileName.match(/-[a-f0-9]{8}/gi) || []).length;
        return bHashCount - aHashCount;
      });
      const sourceFile = sortedFiles[0];
      
      // Create original filename copy (no hash)
      if (baseName !== sourceFile.fileName && !createdOriginals.has(baseName)) {
        const originalPath = path.join(assetDir, baseName);
        if (fs.existsSync(originalPath)) {
          try {
            const stat = fs.statSync(originalPath);
            if (!stat.isFile() || stat.isSymbolicLink()) {
              fs.unlinkSync(originalPath);
            } else {
              return; // Already exists
            }
          } catch (e) {
            // Ignore errors
          }
        }
        
        try {
          fs.copyFileSync(sourceFile.path, originalPath);
          createdOriginals.add(baseName);
          console.log(`Copied ${dirName} file: ${baseName} <- ${sourceFile.fileName}`);
        } catch (copyError) {
          console.warn(`Failed to copy ${dirName} file ${baseName}: ${copyError.message}`);
        }
      }
      
      // Note: We only create the original filename copy (no hash)
      // Hash variations are handled through AssetManifest mappings
      // This preserves cache effectiveness while ensuring files can be found
    });
  });
}

/**
 * Update AssetManifest files to add original path mappings
 * This ensures google_fonts and other packages can find hashed font files
 */
function updateAssetManifests() {
  const assetsDir = path.join(BUILD_DIR, 'assets');
  if (!fs.existsSync(assetsDir)) {
    return;
  }
  
  // Find all AssetManifest files
  const manifestFiles = fs.readdirSync(assetsDir)
    .filter(f => f.startsWith('AssetManifest') && f.endsWith('.json'))
    .map(f => path.join(assetsDir, f));
  
  const doubleAssetsDir = path.join(BUILD_DIR, 'assets', 'assets');
  const hasDoubleAssets = fs.existsSync(doubleAssetsDir);
  
  manifestFiles.forEach(manifestPath => {
    try {
      const content = fs.readFileSync(manifestPath, 'utf8');
      const manifest = JSON.parse(content);
      let updated = false;
      
      // For each path in the manifest, add mappings for original filenames and hash variations
      Object.keys(manifest).forEach(hashedPath => {
        // Extract original path by removing hash suffixes
        const originalPath = hashedPath.replace(/-[a-f0-9]{8}(-[a-f0-9]{8})*\.([^.]+)$/, '.$1');
        
        // Process all asset files (fonts, images, etc.), not just fonts
        if (originalPath !== hashedPath && /\.(ttf|otf|woff|woff2|png|jpg|jpeg|gif|svg|webp|ico|mp3|wav|ogg|mp4|webm)$/i.test(originalPath)) {
          // Get the current value
          let value = manifest[hashedPath];
          
          // If files are in double assets directory, update the value path
          if (hasDoubleAssets && hashedPath.startsWith('assets/')) {
            const relativePath = hashedPath.substring('assets/'.length);
            const dirPath = path.dirname(relativePath);
            const fileName = path.basename(relativePath);
            const baseFileName = fileName.replace(/-[a-f0-9]{8}(-[a-f0-9]{8})*\.([^.]+)$/, '.$1');
            
            // Find the actual file in double assets directory
            const doubleAssetsAssetDir = path.join(doubleAssetsDir, dirPath);
            if (fs.existsSync(doubleAssetsAssetDir)) {
              const files = fs.readdirSync(doubleAssetsAssetDir);
              // Find file that matches the hashed filename or starts with base filename
              const actualFile = files.find(f => {
                return f === fileName || f.startsWith(baseFileName.replace(/\.[^.]+$/, '-'));
              });
              
              if (actualFile) {
                const actualPath = path.join(dirPath, actualFile).replace(/\\/g, '/');
                value = [`assets/assets/${actualPath}`];
                
                // Update the hashed path value
                if (JSON.stringify(value) !== JSON.stringify(manifest[hashedPath])) {
                  manifest[hashedPath] = value;
                  updated = true;
                }
              }
            }
          }
          
          // Add mapping for original path (single assets)
          if (!manifest[originalPath]) {
            manifest[originalPath] = value;
            updated = true;
            console.log(`Added AssetManifest mapping: ${originalPath} -> ${JSON.stringify(value)}`);
          }
          
          // Add mapping for double assets original path
          if (hasDoubleAssets && originalPath.startsWith('assets/')) {
            const doubleAssetsOriginalPath = `assets/assets/${originalPath.substring('assets/'.length)}`;
            if (!manifest[doubleAssetsOriginalPath]) {
              manifest[doubleAssetsOriginalPath] = value;
              updated = true;
              console.log(`Added AssetManifest mapping: ${doubleAssetsOriginalPath} -> ${JSON.stringify(value)}`);
            }
          }
          
          // Add mappings for intermediate hash variations (e.g., 2 hashes, 3 hashes)
          // Extract hash count from hashedPath
          const hashMatches = hashedPath.match(/(-[a-f0-9]{8})+/gi);
          if (hashMatches && hashMatches.length > 1) {
            // Create mappings for all hash variations (1 hash, 2 hashes, etc.)
            for (let i = 1; i < hashMatches.length; i++) {
              const partialHash = hashMatches.slice(0, i).join('');
              const extMatch = originalPath.match(/\.([^.]+)$/);
              if (!extMatch) continue;
              const extension = extMatch[0];
              const nameWithoutExt = originalPath.substring(0, originalPath.length - extension.length);
              const partialPath = nameWithoutExt + partialHash + extension;
              
              // Only add if it doesn't exist and is different from hashedPath
              if (partialPath !== hashedPath && !manifest[partialPath]) {
                manifest[partialPath] = value;
                updated = true;
                console.log(`Added AssetManifest mapping: ${partialPath} -> ${JSON.stringify(value)}`);
              }
              
              // Also add double assets version
              if (hasDoubleAssets && partialPath.startsWith('assets/')) {
                const doubleAssetsPartialPath = `assets/assets/${partialPath.substring('assets/'.length)}`;
                if (!manifest[doubleAssetsPartialPath]) {
                  manifest[doubleAssetsPartialPath] = value;
                  updated = true;
                  console.log(`Added AssetManifest mapping: ${doubleAssetsPartialPath} -> ${JSON.stringify(value)}`);
                }
              }
            }
          }
        }
      });
      
      if (updated) {
        fs.writeFileSync(manifestPath, JSON.stringify(manifest), 'utf8');
        console.log(`Updated ${path.basename(manifestPath)}`);
      }
    } catch (error) {
      console.warn(`Failed to update ${path.basename(manifestPath)}: ${error.message}`);
    }
  });
}

/**
 * Main optimization process
 */
function optimize() {
  console.log('=== Flutter Web Build Optimizer ===\n');
  
  if (!fs.existsSync(BUILD_DIR)) {
    console.error(`Error: Build directory not found: ${BUILD_DIR}`);
    console.error('Please run "flutter build web" first.');
    process.exit(1);
  }
  
  // Step 1: Split main.dart.js first (if exists) before hashing
  const mainDartJsPath = path.join(BUILD_DIR, 'main.dart.js');
  let chunkInfo = null;
  let loaderPath = null;
  
  if (fs.existsSync(mainDartJsPath)) {
    console.log('Step 1: Splitting main.dart.js...\n');
    chunkInfo = splitMainDartJs(mainDartJsPath);
    loaderPath = createChunkLoader(chunkInfo);
  }
  
  // Step 2: Update flutter_bootstrap.js BEFORE hashing (if chunks were created)
  // This ensures we can find the file by its original name
  if (chunkInfo && loaderPath) {
    console.log('\nStep 2: Updating flutter_bootstrap.js with chunk loader...\n');
    const bootstrapPath = path.join(BUILD_DIR, 'flutter_bootstrap.js');
    if (fs.existsSync(bootstrapPath)) {
      let bootstrapContent = fs.readFileSync(bootstrapPath, 'utf8');
      // Replace mainJsPath reference with temporary loader path
      // We'll update it again after hashing with the final hashed path
      bootstrapContent = bootstrapContent.replace(
        /"mainJsPath"\s*:\s*"main\.dart\.js"/g,
        `"mainJsPath": "${loaderPath}"`
      );
      bootstrapContent = bootstrapContent.replace(
        /mainJsPath\s*:\s*"main\.dart\.js"/g,
        `mainJsPath: "${loaderPath}"`
      );
      fs.writeFileSync(bootstrapPath, bootstrapContent, 'utf8');
      console.log('Updated flutter_bootstrap.js to use chunk loader');
    }
  }
  
  // Step 3: Hash all files (except index.html)
  console.log('\nStep 3: Hashing resource files...\n');
  const allFiles = findAllFiles(BUILD_DIR);
  
  // Hash all files including chunks, loader, and flutter_bootstrap.js
  allFiles.forEach(filePath => {
    hashFile(filePath);
  });
  
  // Step 4: Update chunk loader with hashed chunk paths if chunks were created
  if (chunkInfo && loaderPath) {
    console.log('\nStep 4: Updating chunk loader with hashed paths...\n');
    const hashedChunkFiles = chunkInfo.chunkFiles.map(chunk => {
      return resourceMap.get(chunk) || chunk;
    });
    chunkInfo.chunkFiles = hashedChunkFiles;
    
    // Remove all existing chunk-loader files (including hashed ones)
    const existingLoaders = fs.readdirSync(BUILD_DIR)
      .filter(f => f.startsWith('chunk-loader-main.dart') && f.endsWith('.js'))
      .map(f => path.join(BUILD_DIR, f));
    existingLoaders.forEach(loaderFile => {
      fs.unlinkSync(loaderFile);
      console.log(`Removed old loader: ${path.basename(loaderFile)}`);
    });
    
    // Also remove from resourceMap if it was hashed
    const originalLoaderPath = `chunk-loader-main.dart.js`;
    if (resourceMap.has(originalLoaderPath)) {
      resourceMap.delete(originalLoaderPath);
    }
    // Remove any hashed versions from resourceMap
    Array.from(resourceMap.entries()).forEach(([key, value]) => {
      if (key.includes('chunk-loader-main.dart') || value.includes('chunk-loader-main.dart')) {
        resourceMap.delete(key);
      }
    });
    
    // Create new loader with hashed chunk paths
    loaderPath = createChunkLoader(chunkInfo);
    
    // Hash the new loader
    const newLoaderPath = path.join(BUILD_DIR, loaderPath);
    if (fs.existsSync(newLoaderPath)) {
      hashFile(newLoaderPath);
      loaderPath = resourceMap.get(loaderPath) || loaderPath;
    }
    
    // Find and update the hashed flutter_bootstrap-*.js file
    console.log('\nStep 5: Updating hashed flutter_bootstrap.js...\n');
    const bootstrapFiles = fs.readdirSync(BUILD_DIR)
      .filter(f => f.startsWith('flutter_bootstrap-') && f.endsWith('.js'))
      .map(f => path.join(BUILD_DIR, f));
    
    if (bootstrapFiles.length === 0) {
      console.warn('Warning: No flutter_bootstrap-*.js file found');
    } else {
      bootstrapFiles.forEach(bootstrapPath => {
        let bootstrapContent = fs.readFileSync(bootstrapPath, 'utf8');
        const originalContent = bootstrapContent;
        
        // Update mainJsPath in buildConfig JSON
        // Pattern: "mainJsPath":"chunk-loader-main.dart-xxx.js" or "mainJsPath":"main.dart.js"
        bootstrapContent = bootstrapContent.replace(
          /"mainJsPath"\s*:\s*"[^"]*"/g,
          `"mainJsPath": "${loaderPath}"`
        );
        
        // Also handle minified code without quotes around property name
        bootstrapContent = bootstrapContent.replace(
          /mainJsPath\s*:\s*"[^"]*"/g,
          `mainJsPath: "${loaderPath}"`
        );
        
        // Update entrypointUrl default value if present
        bootstrapContent = bootstrapContent.replace(
          /entrypointUrl\s*:\s*i\s*=\s*l\("main\.dart\.js"\)/g,
          `entrypointUrl: i = l("${loaderPath}")`
        );
        
        // Force use local CanvasKit instead of CDN
        // The T function returns CDN URL when engineRevision exists and useLocalCanvasKit is false
        // We need to force it to return "canvaskit" (local path)
        
        // Pattern 1: Replace the entire ternary expression
        bootstrapContent = bootstrapContent.replace(
          /t\.engineRevision\&\&!t\.useLocalCanvasKit\?C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit",t\.engineRevision\):"canvaskit"/g,
          '"canvaskit"'
        );
        
        // Pattern 2: Replace with different spacing
        bootstrapContent = bootstrapContent.replace(
          /t\.engineRevision\s*\&\&\s*!t\.useLocalCanvasKit\s*\?\s*C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit",\s*t\.engineRevision\)\s*:\s*"canvaskit"/g,
          '"canvaskit"'
        );
        
        // Pattern 3: Replace the function T to always return "canvaskit"
        // function T(n,t){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:t.engineRevision&&!t.useLocalCanvasKit?C("https://www.gstatic.com/flutter-canvaskit",t.engineRevision):"canvaskit"}
        bootstrapContent = bootstrapContent.replace(
          /function T\([^)]*\)\{[^}]*return[^}]*\?[^}]*C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit"[^}]*:"canvaskit"[^}]*\}/g,
          'function T(n,t){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:"canvaskit"}'
        );
        
        // Pattern 4: More aggressive - replace any CDN URL construction
        bootstrapContent = bootstrapContent.replace(
          /C\("https:\/\/www\.gstatic\.com\/flutter-canvaskit"[^)]*\)/g,
          '"canvaskit"'
        );
        
        if (bootstrapContent !== originalContent) {
          fs.writeFileSync(bootstrapPath, bootstrapContent, 'utf8');
          console.log(`Updated ${path.basename(bootstrapPath)} with hashed loader path: ${loaderPath}`);
        } else {
          console.log(`No changes needed for ${path.basename(bootstrapPath)}`);
        }
      });
    }
  }
  
  // Step 6: Create copies for original canvaskit filenames
  console.log('\nStep 6: Creating canvaskit original file copies...\n');
  createCanvaskitOriginals();
  
  // Step 7: Create symlinks for original font filenames
  console.log('\nStep 7: Creating font symlinks...\n');
  createFontSymlinks();
  
  // Step 8: Update AssetManifest files to map original paths to hashed paths
  console.log('\nStep 8: Updating AssetManifest files...\n');
  updateAssetManifests();
  
  // Step 9: Update all file references (including Service Worker files)
  console.log('\nStep 9: Updating file references...\n');
  const filesToUpdate = findAllFiles(BUILD_DIR);
  filesToUpdate.forEach(filePath => {
    // Update references in text files
    const ext = getExtension(filePath).toLowerCase();
    if (['.html', '.js', '.json', '.css', '.dart'].includes(ext)) {
      updateFileReferences(filePath);
    }
  });
  
  // Also update index.html references
  const indexPath = path.join(BUILD_DIR, INDEX_HTML);
  updateFileReferences(indexPath);
  
  // Step 10: Update Service Worker files specifically
  console.log('\nStep 10: Updating Service Worker files...\n');
  const serviceWorkerFiles = fs.readdirSync(BUILD_DIR)
    .filter(f => f.startsWith('flutter_service_worker-') && f.endsWith('.js'))
    .map(f => path.join(BUILD_DIR, f));
  
  serviceWorkerFiles.forEach(swPath => {
    updateFileReferences(swPath);
    console.log(`Updated Service Worker: ${path.basename(swPath)}`);
  });
  
  console.log('\n=== Optimization Complete ===');
  console.log(`Total files hashed: ${resourceMap.size}`);
  if (chunkInfo) {
    console.log(`Main file split into ${chunkInfo.chunkCount} chunks`);
  }
}

// Run optimization
optimize();

